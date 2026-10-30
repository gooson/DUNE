#!/bin/bash
# Shared simulator boot helper.
# Source this from test scripts: source "$ROOT_DIR/scripts/lib/simulator-boot.sh"

# Print available simulator runtimes for diagnostics.
_dump_simulator_diagnostics() {
    echo "── Simulator Diagnostics ──"
    echo "Available runtimes:"
    python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 30 -- xcrun simctl list runtimes 2>&1 || true
    echo ""
    echo "Device state for target UDID ($1):"
    python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 30 -- xcrun simctl list devices 2>&1 | grep -A2 "$1" | head -10 || true
    echo "── End Diagnostics ──"
}

# Attempt a single boot cycle: boot → poll until Booted or timeout.
# Uses stepped backoff: 2s → 4s → 6s → ... → 10s (capped).
# Returns 0 on success, 1 on timeout.
_try_boot() {
    # One monotonic deadline includes bootstatus, fallback queries and sleeps.
    ROOT_DIR="$ROOT_DIR" python3 "$ROOT_DIR/scripts/lib/command-deadline.py" \
        --seconds "$3" -- bash -c 'source "$1"; _try_boot_cycle "$2" "$3" "$4"' \
        boot-cycle "$ROOT_DIR/scripts/lib/simulator-boot.sh" "$1" "$2" "$3"
}

_try_boot_cycle() {
    local udid="$1"
    local label="$2"
    local timeout="$3"
    local elapsed=0
    local interval=2

    local boot_err
    boot_err=$(python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 30 -- xcrun simctl boot "$udid" 2>&1) || true
    if [[ -n "$boot_err" ]]; then
        # "Unable to boot device in current state: Booted" is fine
        if echo "$boot_err" | grep -q "Booted"; then
            echo "${label} simulator already booted."
            return 0
        fi
        echo "simctl boot stderr: ${boot_err:0:200}"
    fi

    # Poll with bootstatus first (faster, blocks until ready), fall back to list devices.
    # bootstatus exits 0 when booted; we give it most of the remaining timeout.
    if python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds "$timeout" -- xcrun simctl bootstatus "$udid" -b 2>/dev/null; then
        echo "${label} simulator booted (bootstatus confirmed)."
        return 0
    fi

    # Fallback: poll simctl list devices. Use generous 30s sub-timeout because
    # the CoreSimulator daemon can be slow to respond while booting.
    while [[ "$elapsed" -lt "$timeout" ]]; do
        if python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 30 -- xcrun simctl list devices 2>/dev/null | grep -F "$udid" | grep -q "Booted"; then
            echo "${label} simulator booted (${elapsed}s)."
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
        [[ "$interval" -lt 10 ]] && interval=$((interval + 2))
    done

    return 1
}

# Wait for a simulator to reach Booted state with timeout and retry.
# Usage: wait_for_simulator_boot <UDID> <label>
#
# Environment:
#   SIMULATOR_BOOT_TIMEOUT  - seconds per attempt (default: 120, CI recommended: 300)
#   SIMULATOR_BOOT_RETRIES  - number of retry attempts after first failure (default: 1, CI recommended: 2)
#
# Exits 1 if the simulator fails to boot after all attempts.
wait_for_simulator_boot() {
    local udid="$1"
    local label="$2"
    local timeout="${SIMULATOR_BOOT_TIMEOUT:-120}"
    local max_retries="${SIMULATOR_BOOT_RETRIES:-1}"
    local attempt=0

    # Validate env var inputs
    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [[ "$timeout" -eq 0 ]]; then
        echo "ERROR: SIMULATOR_BOOT_TIMEOUT must be a positive integer (got: '$timeout')."
        exit 1
    fi
    if ! [[ "$max_retries" =~ ^[0-9]+$ ]]; then
        echo "ERROR: SIMULATOR_BOOT_RETRIES must be a non-negative integer (got: '$max_retries')."
        exit 1
    fi

    echo "Waiting for ${label} simulator [$udid] to boot (timeout=${timeout}s, retries=${max_retries})..."

    # Drain the listing: grep -q can close the pipe early and turn a match into
    # an upstream SIGPIPE failure when the caller enables pipefail.
    if ! python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 30 -- xcrun simctl list devices 2>/dev/null | grep -F "$udid" >/dev/null; then
        echo "ERROR: Simulator UDID [$udid] not found in device list."
        _dump_simulator_diagnostics "$udid"
        exit 1
    fi

    while [[ "$attempt" -le "$max_retries" ]]; do
        if [[ "$attempt" -gt 0 ]]; then
            echo "Retry $attempt/$max_retries: shutting down and rebooting ${label} simulator..."
            python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 30 -- xcrun simctl shutdown "$udid" 2>/dev/null || true
            sleep 3
        fi

        if _try_boot "$udid" "$label" "$timeout"; then
            return 0
        fi

        echo "WARNING: ${label} simulator did not boot within ${timeout}s (attempt $((attempt + 1))/$((max_retries + 1)))."
        attempt=$((attempt + 1))
    done

    echo "ERROR: ${label} simulator failed to boot after $((max_retries + 1)) attempts."
    _dump_simulator_diagnostics "$udid"
    exit 1
}
