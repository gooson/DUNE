#!/bin/bash
# Worktree-isolated simulator management.
# Source this from test scripts: source "$ROOT_DIR/scripts/lib/simulator-worktree.sh"
#
# When running inside a git worktree, clones the resolved simulator so that
# multiple worktrees can run tests concurrently without sharing a device.
# In the main repo (non-worktree), returns the original UDID unchanged.

# Cached worktree state (populated on first call)
_WT_TOPLEVEL=""
_WT_IS_WORKTREE=""  # "yes" | "no" | "" (unset)
_WT_BASENAME=""
_SIM_WORKTREE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A stuck CoreSimulator query or clone must not consume the whole test deadline.
_simctl_bounded() {
    local seconds="$1"
    shift
    python3 "$_SIM_WORKTREE_LIB_DIR/command-deadline.py" --seconds "$seconds" -- xcrun simctl "$@"
}

# Populate worktree cache once.
_ensure_worktree_cache() {
    if [[ -n "$_WT_IS_WORKTREE" ]]; then
        return
    fi

    _WT_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)" || { _WT_IS_WORKTREE="no"; return; }

    # Codex worktrees can share a basename (e.g. <id>/Health).
    # Include the full path identity so concurrent worktrees never reuse a device.
    local path_hash
    path_hash=$(printf '%s' "$_WT_TOPLEVEL" | shasum -a 256) || {
        echo >&2 "Error: Cannot compute worktree identity for simulator isolation."
        return 1
    }
    # Show the worktree directory (e.g. 8d4b) as well as a path hash. The
    # directory is useful in Simulator.app; the hash prevents name collisions.
    local worktree_label
    worktree_label=$(basename "$(dirname "$_WT_TOPLEVEL")" | tr -cs '[:alnum:]' '-')
    worktree_label="${worktree_label#-}"
    worktree_label="${worktree_label%-}"
    _WT_BASENAME="$(basename "$_WT_TOPLEVEL")-${worktree_label}-${path_hash:0:12}"

    # In a worktree, .git is a file (not a directory) pointing to the main repo
    if [[ -f "$_WT_TOPLEVEL/.git" ]]; then
        _WT_IS_WORKTREE="yes"
        return
    fi

    # Main repo: .git is a directory. Compare git-common-dir to confirm.
    local common_dir
    common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || { _WT_IS_WORKTREE="no"; return; }
    local resolved_common
    resolved_common="$(cd "$_WT_TOPLEVEL" && cd "$common_dir" && pwd)"
    local resolved_git_dir
    resolved_git_dir="$(cd "$_WT_TOPLEVEL/.git" && pwd)"

    if [[ "$resolved_common" != "$resolved_git_dir" ]]; then
        _WT_IS_WORKTREE="yes"
    else
        _WT_IS_WORKTREE="no"
    fi
}

# Returns 0 (true) if worktree, 1 (false) if main repo.
_is_git_worktree() {
    _ensure_worktree_cache
    [[ "$_WT_IS_WORKTREE" == "yes" ]]
}

# Get the path-qualified worktree key (e.g., "Health-8d4b-a1b2c3d4e5f6").
_worktree_basename() {
    _ensure_worktree_cache || return 1
    echo "$_WT_BASENAME"
}

# Wait for a simulator to reach Shutdown state (max wait_secs).
_wait_for_shutdown() {
    local udid="$1"
    local max_wait="${2:-15}"
    local elapsed=0
    while [[ "$elapsed" -lt "$max_wait" ]]; do
        local state
        state=$(SIMCTL_UDID="$udid" _simctl_bounded 30 list devices -j 2>/dev/null \
            | SIMCTL_UDID="$udid" python3 -c "
import json, os, sys
udid = os.environ['SIMCTL_UDID']
data = json.load(sys.stdin)
for devs in data.get('devices', {}).values():
    for d in devs:
        if d.get('udid') == udid:
            print(d.get('state', ''))
            sys.exit(0)
" 2>/dev/null) || true
        [[ "$state" == "Shutdown" ]] && return 0
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

# Query simulators by name. Prints UDID if found.
# Usage: _find_simulator_by_name <name>
_find_simulator_by_name() {
    local target_name="$1"
    local devices_json
    devices_json=$(_simctl_bounded 30 list devices available -j 2>/dev/null) || return 1
    SIMCTL_TARGET="$target_name" python3 -c "
import json, os, sys
data = json.load(sys.stdin)
target = os.environ['SIMCTL_TARGET']
for runtime, devices in data.get('devices', {}).items():
    for device in devices:
        if device.get('name') == target and device.get('isAvailable', True):
            print(device['udid'])
            sys.exit(0)
sys.exit(0)
" 2>/dev/null <<< "$devices_json"
}

# Query simulators matching a pattern. Prints "udid\tname" per line.
# Usage: _find_simulators_matching <pattern>
_find_simulators_matching() {
    local pattern="$1"
    SIMCTL_PATTERN="$pattern" _simctl_bounded 30 list devices available -j 2>/dev/null \
        | SIMCTL_PATTERN="$pattern" python3 -c "
import json, os, sys
data = json.load(sys.stdin)
pattern = os.environ['SIMCTL_PATTERN']
for runtime, devices in data.get('devices', {}).items():
    for device in devices:
        name = device.get('name', '')
        if pattern in name:
            print(f'{device[\"udid\"]}\t{name}')
" 2>/dev/null
}

# Ensure a worktree-specific simulator clone exists and print its UDID.
# Usage: ensure_worktree_simulator <source-udid> <simulator-name>
# If not in a worktree, prints the source UDID unchanged.
ensure_worktree_simulator() {
    local source_udid="$1"
    local sim_name="$2"

    # Guard: reject empty UDID
    if [[ -z "$source_udid" || ! "$source_udid" =~ ^[0-9A-Fa-f-]+$ ]]; then
        echo >&2 "Warning: Invalid source UDID '$source_udid'. Returning as-is."
        echo "$source_udid"
        return 0
    fi

    _ensure_worktree_cache || return 1
    if ! _is_git_worktree; then
        echo "$source_udid"
        return 0
    fi

    local wt_name
    wt_name="$(_worktree_basename)"
    local clone_name="${sim_name}-wt-${wt_name}"

    # Check if clone already exists
    local existing_udid
    if ! existing_udid=$(_find_simulator_by_name "$clone_name"); then
        echo >&2 "Error: Could not query simulator '$clone_name'; refusing to clone."
        return 1
    fi

    if [[ -n "$existing_udid" ]]; then
        if python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" is-orphan \
            "$_WT_TOPLEVEL" "$existing_udid"; then
            echo >&2 "Error: Simulator '$clone_name' [$existing_udid] has an unresolved orphan marker."
            return 1
        fi
        if ! python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" is-recorded \
            "$_WT_TOPLEVEL" "$existing_udid" "$clone_name"; then
            echo >&2 "Warning: Reusing unrecorded simulator '$clone_name' [$existing_udid]; Ship will preserve it."
        fi
        echo >&2 "Reusing worktree simulator '$clone_name' [$existing_udid]"
        echo "$existing_udid"
        return 0
    fi

    # Clone the source simulator (must be shutdown first)
    local baseline_file
    baseline_file=$(mktemp)
    if ! _simctl_bounded 30 list devices -j >"$baseline_file"; then
        rm -f "$baseline_file"
        echo >&2 "Error: Could not capture simulator baseline before clone."
        return 1
    fi
    echo >&2 "Creating worktree simulator '$clone_name' from [$source_udid]..."
    _simctl_bounded 30 shutdown "$source_udid" 2>/dev/null || true
    _wait_for_shutdown "$source_udid" 15

    local new_udid clone_err_file clone_exit
    clone_err_file=$(mktemp)
    if new_udid=$(_simctl_bounded 180 clone "$source_udid" "$clone_name" 2>"$clone_err_file"); then
        clone_exit=0
    else
        clone_exit=$?
    fi
    local clone_err
    clone_err=$(cat "$clone_err_file" 2>/dev/null)
    rm -f "$clone_err_file"

    if [[ $clone_exit -ne 0 || -z "$new_udid" ]]; then
        [[ -n "$clone_err" ]] && echo >&2 "Clone error: $clone_err"
        if ! python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" reconcile-clone \
            "$_WT_TOPLEVEL" "$clone_name" "$baseline_file"; then
            echo >&2 "Error: Clone reconciliation is uncertain; baseline preserved at $baseline_file."
            return 1
        fi
        rm -f "$baseline_file"
        echo >&2 "Error: Clone failed; refusing to use shared source [$source_udid]."
        return 1
    fi

    if ! python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" record \
        "$_WT_TOPLEVEL" "$new_udid" "$clone_name" "$baseline_file"; then
        echo >&2 "Error: Could not record ownership of worktree simulator [$new_udid]."
        if python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" rollback-safe \
            "$_WT_TOPLEVEL" "$new_udid" "$clone_name" "$baseline_file"; then
            _simctl_bounded 30 shutdown "$new_udid" 2>/dev/null || true
            _simctl_bounded 30 delete "$new_udid" 2>/dev/null || \
                echo >&2 "Warning: rollback delete failed for [$new_udid]."
        fi
        rm -f "$baseline_file"
        if ! python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" absent \
            "$_WT_TOPLEVEL" "$new_udid"; then
            python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" mark-orphan \
                "$_WT_TOPLEVEL" "$new_udid" "$clone_name" || \
                echo >&2 "ERROR: Could not persist orphan marker for [$new_udid]."
            echo >&2 "ERROR: Untracked simulator '$clone_name' [$new_udid] remains or could not be verified."
            echo >&2 "Review this UDID manually before removing the worktree."
        fi
        return 1
    fi
    rm -f "$baseline_file"

    echo >&2 "Created worktree simulator '$clone_name' [$new_udid]"
    echo "$new_udid"
}

# Remove a previously recorded clone of this exact device before a fresh test run.
reset_worktree_simulator() {
    local sim_name="$1"
    _ensure_worktree_cache || return 1
    if ! _is_git_worktree; then
        echo >&2 "Shared simulator '$sim_name' is not worktree-owned; preserving it."
        return 0
    fi
    local clone_name="${sim_name}-wt-$(_worktree_basename)"
    local existing_udid
    if ! existing_udid=$(_find_simulator_by_name "$clone_name"); then
        echo >&2 "Error: Could not query simulator '$clone_name'; refusing to reset."
        return 1
    fi
    if [[ -z "$existing_udid" ]]; then
        return 0
    fi
    if ! python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" is-recorded \
        "$_WT_TOPLEVEL" "$existing_udid" "$clone_name"; then
        echo >&2 "Cannot reset unrecorded watch simulator '$clone_name' [$existing_udid]."
        return 1
    fi
    python3 "$_SIM_WORKTREE_LIB_DIR/command-deadline.py" --seconds 180 -- \
        python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" cleanup-name \
        "$_WT_TOPLEVEL" "$clone_name"
}

# Apply worktree simulator isolation to a destination string.
# Usage: apply_worktree_destination <destination> <sim-name> <platform>
# Extracts UDID from destination, clones if in worktree, returns new destination.
apply_worktree_destination() {
    local destination="$1"
    local sim_name="$2"
    local platform="$3"

    _ensure_worktree_cache || return 1
    if ! _is_git_worktree; then
        echo "$destination"
        return 0
    fi

    local udid
    if [[ "$destination" =~ id=([0-9A-Fa-f-]+) ]]; then
        udid="${BASH_REMATCH[1]}"
    else
        echo "$destination"
        return 0
    fi

    local new_udid
    new_udid=$(ensure_worktree_simulator "$udid" "$sim_name")
    echo "platform=${platform} Simulator,id=${new_udid}"
}

# Delete worktree simulators.
# Usage: cleanup_worktree_simulators [--owned | --current | --all]
cleanup_worktree_simulators() {
    local mode="${1:---owned}"
    local pattern

    case "$mode" in
        --owned|--current)
            _ensure_worktree_cache || return 1
            if ! _is_git_worktree; then
                echo "Not in a worktree. Nothing to clean up."
                return 0
            fi
            python3 "$_WT_TOPLEVEL/scripts/lib/worktree-simulator-registry.py" cleanup "$_WT_TOPLEVEL"
            return $?
            ;;
        --all)
            pattern="-wt-"
            ;;
        *)
            echo "Usage: cleanup_worktree_simulators [--owned | --current | --all]"
            return 1
            ;;
    esac

    local devices_to_delete
    devices_to_delete=$(_find_simulators_matching "$pattern") || true

    if [[ -z "$devices_to_delete" ]]; then
        echo "No worktree simulators to clean up."
        return 0
    fi

    local count=0
    while IFS=$'\t' read -r udid name; do
        echo "Deleting simulator '$name' [$udid]..."
        _simctl_bounded 30 shutdown "$udid" 2>/dev/null || true
        _wait_for_shutdown "$udid" 10
        _simctl_bounded 30 delete "$udid" 2>/dev/null || true
        count=$((count + 1))
    done <<< "$devices_to_delete"

    echo "Cleaned up $count worktree simulator(s)."
}

# Allow running as standalone script for cleanup
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --cleanup-all)
            cleanup_worktree_simulators --all
            ;;
        --cleanup-current)
            cleanup_worktree_simulators --owned
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--cleanup-all | --cleanup-current]"
            echo ""
            echo "  --cleanup-all      Delete all worktree simulators (*-wt-*)"
            echo "  --cleanup-current  Delete recorded simulators created by this worktree"
            ;;
        *)
            echo "Usage: $(basename "$0") [--cleanup-all | --cleanup-current]"
            exit 1
            ;;
    esac
fi
