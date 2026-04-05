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

# Populate worktree cache once.
_ensure_worktree_cache() {
    if [[ -n "$_WT_IS_WORKTREE" ]]; then
        return
    fi

    _WT_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)" || { _WT_IS_WORKTREE="no"; return; }

    # In a worktree, .git is a file (not a directory) pointing to the main repo
    if [[ -f "$_WT_TOPLEVEL/.git" ]]; then
        _WT_IS_WORKTREE="yes"
        _WT_BASENAME="$(basename "$_WT_TOPLEVEL")"
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
        _WT_BASENAME="$(basename "$_WT_TOPLEVEL")"
    else
        _WT_IS_WORKTREE="no"
    fi
}

# Returns 0 (true) if worktree, 1 (false) if main repo.
_is_git_worktree() {
    _ensure_worktree_cache
    [[ "$_WT_IS_WORKTREE" == "yes" ]]
}

# Get the worktree basename (e.g., "determined-maxwell").
_worktree_basename() {
    _ensure_worktree_cache
    echo "$_WT_BASENAME"
}

# Wait for a simulator to reach Shutdown state (max wait_secs).
_wait_for_shutdown() {
    local udid="$1"
    local max_wait="${2:-15}"
    local elapsed=0
    while [[ "$elapsed" -lt "$max_wait" ]]; do
        local state
        state=$(SIMCTL_UDID="$udid" xcrun simctl list devices -j 2>/dev/null \
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
    SIMCTL_TARGET="$target_name" xcrun simctl list devices available -j 2>/dev/null \
        | SIMCTL_TARGET="$target_name" python3 -c "
import json, os, sys
data = json.load(sys.stdin)
target = os.environ['SIMCTL_TARGET']
for runtime, devices in data.get('devices', {}).items():
    for device in devices:
        if device.get('name') == target and device.get('isAvailable', True):
            print(device['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# Query simulators matching a pattern. Prints "udid\tname" per line.
# Usage: _find_simulators_matching <pattern>
_find_simulators_matching() {
    local pattern="$1"
    SIMCTL_PATTERN="$pattern" xcrun simctl list devices available -j 2>/dev/null \
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

    if ! _is_git_worktree; then
        echo "$source_udid"
        return 0
    fi

    local wt_name
    wt_name="$(_worktree_basename)"
    local clone_name="${sim_name}-wt-${wt_name}"

    # Check if clone already exists
    local existing_udid
    existing_udid=$(_find_simulator_by_name "$clone_name") || true

    if [[ -n "$existing_udid" ]]; then
        echo >&2 "Reusing worktree simulator '$clone_name' [$existing_udid]"
        echo "$existing_udid"
        return 0
    fi

    # Clone the source simulator (must be shutdown first)
    echo >&2 "Creating worktree simulator '$clone_name' from [$source_udid]..."
    xcrun simctl shutdown "$source_udid" 2>/dev/null || true
    _wait_for_shutdown "$source_udid" 15

    local new_udid clone_err_file clone_exit
    clone_err_file=$(mktemp)
    new_udid=$(xcrun simctl clone "$source_udid" "$clone_name" 2>"$clone_err_file")
    clone_exit=$?
    local clone_err
    clone_err=$(cat "$clone_err_file" 2>/dev/null)
    rm -f "$clone_err_file"

    if [[ $clone_exit -ne 0 || -z "$new_udid" ]]; then
        [[ -n "$clone_err" ]] && echo >&2 "Clone error: $clone_err"
        echo >&2 "Warning: Failed to clone simulator. Falling back to source [$source_udid]."
        # Re-boot the source since we shut it down
        xcrun simctl boot "$source_udid" 2>/dev/null || true
        echo "$source_udid"
        return 0
    fi

    echo >&2 "Created worktree simulator '$clone_name' [$new_udid]"
    echo "$new_udid"
}

# Apply worktree simulator isolation to a destination string.
# Usage: apply_worktree_destination <destination> <sim-name> <platform>
# Extracts UDID from destination, clones if in worktree, returns new destination.
apply_worktree_destination() {
    local destination="$1"
    local sim_name="$2"
    local platform="$3"

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
# Usage: cleanup_worktree_simulators [--current | --all]
cleanup_worktree_simulators() {
    local mode="${1:---current}"
    local pattern

    case "$mode" in
        --current)
            if ! _is_git_worktree; then
                echo "Not in a worktree. Nothing to clean up."
                return 0
            fi
            pattern="-wt-$(_worktree_basename)"
            ;;
        --all)
            pattern="-wt-"
            ;;
        *)
            echo "Usage: cleanup_worktree_simulators [--current | --all]"
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
        xcrun simctl shutdown "$udid" 2>/dev/null || true
        _wait_for_shutdown "$udid" 10
        xcrun simctl delete "$udid" 2>/dev/null || true
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
            cleanup_worktree_simulators --current
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--cleanup-all | --cleanup-current]"
            echo ""
            echo "  --cleanup-all      Delete all worktree simulators (*-wt-*)"
            echo "  --cleanup-current  Delete simulators for current worktree only"
            ;;
        *)
            echo "Usage: $(basename "$0") [--cleanup-all | --cleanup-current]"
            exit 1
            ;;
    esac
fi
