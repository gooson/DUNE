#!/bin/bash
# Run one route-focused screenshot batch on an explicit isolated simulator.
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 regular|ipad|duo|duo-open GROUP SIMULATOR_UDID (GROUP is a capture-tests-*.txt suffix)" >&2
    exit 2
fi

device="$1"
group="$2"
udid="$3"
root="$(cd "$(dirname "$0")/../../.." && pwd)"
target_file="$root/docs/design/phone-design-map/capture-tests-${group}.txt"
if [[ ! -f "$target_file" ]]; then
    echo "Unknown capture group: $group" >&2
    exit 2
fi

args=(--no-regen --test-plan DUNEUITests-DesignCapture --simulator-udid "$udid"
      --log-file ".xcodebuild/capture-${device}-${group}.log")
while IFS= read -r selector; do
    [[ -z "$selector" ]] && continue
    args+=(--only-testing "$selector")
done < "$target_file"

cd "$root"
exec scripts/test-ui.sh "${args[@]}"
