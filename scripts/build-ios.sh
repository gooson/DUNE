#!/bin/bash
# Standard iOS build check for DUNE.
# - Regenerates project from xcodegen (unless --no-regen)
# - Builds with iOS destination, resolving to an available simulator when possible
# - Prints concise failure summary

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNE"
SIM_NAME="${DUNE_SIM_NAME:-iPhone 17}"
SIM_OS="${DUNE_SIM_OS:-26.2}"
DESTINATION="${DAILVE_IOS_DESTINATION:-platform=iOS Simulator,name=${SIM_NAME},OS=${SIM_OS}}"
DERIVED_DATA_DIR=".deriveddata"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/ios-build.log"
REGENERATE=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-regen)
            REGENERATE=0
            shift
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen] [--log-file <path>]"
            exit 2
            ;;
    esac
done

mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
regen_project

resolve_ios_destination() {
    local sim_name="$1"
    local sim_os="$2"
    local requested="platform=iOS Simulator,name=${sim_name},OS=${sim_os}"
    local available_json
    local runtime_prefix
    runtime_prefix="iOS-${sim_os//./-}"
    local exact_match_id

    available_json="$(xcrun simctl list devices available -j 2>/dev/null || true)"

    exact_match_id=$(SIM_NAME_VALUE="${sim_name}" RUNTIME_PREFIX="${runtime_prefix}" python3 -c "
import json, os, sys
data = json.load(sys.stdin)
runtime_prefix = os.environ.get('RUNTIME_PREFIX', '')
sim_name = os.environ.get('SIM_NAME_VALUE', '')
for runtime, devices in data.get('devices', {}).items():
    if runtime_prefix not in runtime:
        continue
    for device in devices:
        if not device.get('isAvailable', True):
            continue
        if device.get('name') == sim_name:
            print(device['udid'])
            sys.exit(0)
sys.exit(1)
" <<<"${available_json}" 2>/dev/null) || true

    if [[ -n "${exact_match_id}" ]]; then
        echo "$requested"
        return
    fi

    local runtime_fallback_id
    runtime_fallback_id=$(RUNTIME_PREFIX="${runtime_prefix}" python3 -c "
import json, os, sys
data = json.load(sys.stdin)
runtime_prefix = os.environ.get('RUNTIME_PREFIX', '')
for runtime, devices in data.get('devices', {}).items():
    if runtime_prefix not in runtime:
        continue
    for device in devices:
        if device.get('isAvailable', True):
            print(device['udid'])
            sys.exit(0)
sys.exit(1)
" <<<"${available_json}" 2>/dev/null) || true

    if [[ -n "${runtime_fallback_id}" ]]; then
        echo "platform=iOS Simulator,id=${runtime_fallback_id}"
        return
    fi

    local any_ios_fallback_id
    any_ios_fallback_id=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS-' not in runtime:
        continue
    for device in devices:
        if device.get('isAvailable', True):
            print(device['udid'])
            sys.exit(0)
sys.exit(1)
" <<<"${available_json}" 2>/dev/null) || true

    if [[ -n "${any_ios_fallback_id}" ]]; then
        echo "platform=iOS Simulator,id=${any_ios_fallback_id}"
        return
    fi

    # Final fallback when simulator runtimes are missing on CI image.
    echo "generic/platform=iOS"
}

if [[ -z "${DAILVE_IOS_DESTINATION:-}" ]]; then
    DESTINATION="$(resolve_ios_destination "$SIM_NAME" "$SIM_OS")"
fi

echo "Building scheme '$SCHEME' for destination '$DESTINATION'..."
set +e
xcodebuild -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build >"$LOG_FILE" 2>&1
BUILD_EXIT=$?
set -e

if [[ "$BUILD_EXIT" -ne 0 ]]; then
    echo ""
    echo "Build failed. Summary:"
    grep -n -E "BUILD (SUCCEEDED|FAILED)|error:" "$LOG_FILE" | tail -n 120 || true
    echo ""
    echo "Full log: $LOG_FILE"
    exit "$BUILD_EXIT"
fi

echo "Build succeeded."
grep -n -E "BUILD (SUCCEEDED|FAILED)" "$LOG_FILE" | tail -n 20 || true
