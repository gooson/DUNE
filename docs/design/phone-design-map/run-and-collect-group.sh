#!/bin/bash
# Keep the xcresult from each UI run before Xcode prunes older result bundles.
set -uo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 regular|ipad|duo|duo-open GROUP SIMULATOR_UDID" >&2
    exit 2
fi

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"
previous_result="$(ls -dt .deriveddata/ui-tests/Logs/Test/*.xcresult 2>/dev/null | head -1)"
bash docs/design/phone-design-map/run-capture-group.sh "$1" "$2" "$3"
test_status=$?
latest_result="$(ls -dt .deriveddata/ui-tests/Logs/Test/*.xcresult 2>/dev/null | head -1)"
if [[ -z "$latest_result" || "$latest_result" == "$previous_result" ]]; then
    echo "No new xcresult; test exit: $test_status" >&2
    exit 1
fi
python3 docs/design/phone-design-map/collect-real-captures.py "$1" "$latest_result"
collect_status=$?
echo "CAPTURE_GROUP device=$1 group=$2 test_exit=$test_status collect_exit=$collect_status result=$latest_result"
if [[ "$collect_status" -ne 0 ]]; then
    exit "$collect_status"
fi
exit "$test_status"
