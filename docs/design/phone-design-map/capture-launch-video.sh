#!/bin/bash
# Record the app's real first paint; XCTest mock launches intentionally skip the splash.
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 SIMULATOR_UDID regular|ipad|duo|duo-open OUTPUT.mov" >&2
    exit 2
fi

udid="$1"
device="$2"
output="$3"
root="$(cd "$(dirname "$0")/../../.." && pwd)"

case "$device" in
    regular|ipad) display=primary ;;
    duo) display=1 ;;
    duo-open) display=3 ;;
    *) echo "Unknown device: $device" >&2; exit 2 ;;
esac

cd "$root"
python3 scripts/lib/simulator-test-lock.py "$root" -- bash -c '
    set -euo pipefail
    udid="$1"; display="$2"; output="$3"
    xcrun simctl terminate "$udid" com.raftel.dailve >/dev/null 2>&1 || true
    xcrun simctl io "$udid" recordVideo --codec=h264 "--display=$display" --force "$output" &
    recorder=$!
    trap '\''kill -INT "$recorder" 2>/dev/null || true'\'' EXIT
    sleep 0.5
    xcrun simctl launch "$udid" com.raftel.dailve
    sleep 4
    kill -INT "$recorder" 2>/dev/null || true
    wait "$recorder" || true
    trap - EXIT
' _ "$udid" "$display" "$output"
