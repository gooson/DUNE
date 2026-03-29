#!/bin/bash
# Shared simulator boot helper.
# Source this from test scripts: source "$ROOT_DIR/scripts/lib/simulator-boot.sh"

# Wait for a simulator to reach Booted state with timeout.
# Usage: wait_for_simulator_boot <UDID> <label>
# Exits 1 if the simulator fails to boot within 120 seconds.
wait_for_simulator_boot() {
    local udid="$1"
    local label="$2"
    local timeout=120
    local elapsed=0

    echo "Waiting for ${label} simulator [$udid] to boot..."
    xcrun simctl boot "$udid" 2>/dev/null || true

    while [[ "$elapsed" -lt "$timeout" ]]; do
        if timeout 5 xcrun simctl list devices 2>/dev/null | grep "$udid" | grep -q "Booted"; then
            echo "${label} simulator booted (${elapsed}s)."
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo "ERROR: ${label} simulator failed to boot within ${timeout}s."
    exit 1
}
