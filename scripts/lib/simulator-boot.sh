#!/bin/bash
# Shared simulator boot helper.
# Source this from test scripts: source "$ROOT_DIR/scripts/lib/simulator-boot.sh"

# Print available simulator runtimes for diagnostics.
_dump_simulator_diagnostics() {
    echo "── Simulator Diagnostics ──"
    echo "Available runtimes:"
    xcrun simctl list runtimes 2>&1 || true
    echo ""
    echo "Device state for target UDID ($1):"
    xcrun simctl list devices 2>&1 | grep -A1 "$1" || true
    echo "── End Diagnostics ──"
}

# Attempt a single boot cycle: boot → poll until Booted or timeout.
# Returns 0 on success, 1 on timeout.
_try_boot() {
    local udid="$1"
    local label="$2"
    local timeout="$3"
    local elapsed=0

    local boot_err
    boot_err=$(xcrun simctl boot "$udid" 2>&1) || true
    if [[ -n "$boot_err" ]]; then
        # "Unable to boot device in current state: Booted" is fine
        if echo "$boot_err" | grep -q "Booted"; then
            echo "${label} simulator already booted."
            return 0
        fi
        echo "simctl boot stderr: $boot_err"
    fi

    while [[ "$elapsed" -lt "$timeout" ]]; do
        if timeout 5 xcrun simctl list devices 2>/dev/null | grep "$udid" | grep -q "Booted"; then
            echo "${label} simulator booted (${elapsed}s)."
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    return 1
}

# Wait for a simulator to reach Booted state with timeout and retry.
# Usage: wait_for_simulator_boot <UDID> <label>
#
# Environment:
#   SIMULATOR_BOOT_TIMEOUT  - seconds per attempt (default: 120)
#   SIMULATOR_BOOT_RETRIES  - number of retry attempts after first failure (default: 1)
#
# Exits 1 if the simulator fails to boot after all attempts.
wait_for_simulator_boot() {
    local udid="$1"
    local label="$2"
    local timeout="${SIMULATOR_BOOT_TIMEOUT:-120}"
    local max_retries="${SIMULATOR_BOOT_RETRIES:-1}"
    local attempt=0

    echo "Waiting for ${label} simulator [$udid] to boot (timeout=${timeout}s, retries=${max_retries})..."

    # Pre-flight: verify the device exists
    if ! xcrun simctl list devices 2>/dev/null | grep -q "$udid"; then
        echo "ERROR: Simulator UDID [$udid] not found in device list."
        _dump_simulator_diagnostics "$udid"
        exit 1
    fi

    while [[ "$attempt" -le "$max_retries" ]]; do
        if [[ "$attempt" -gt 0 ]]; then
            echo "Retry $attempt/$max_retries: shutting down and rebooting ${label} simulator..."
            xcrun simctl shutdown "$udid" 2>/dev/null || true
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
