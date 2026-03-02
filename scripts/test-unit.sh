#!/bin/bash
# Run unit tests on iOS + watchOS simulators.
# - Regenerates project from xcodegen (unless --no-regen)
# - Runs DUNETests and DUNEWatchTests sequentially
# - Prints concise failure summary per suite

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
IOS_SCHEME="DUNETests"
IOS_SIM_NAME="${DUNE_SIM_NAME:-iPhone 17}"
IOS_SIM_OS="${DUNE_SIM_OS:-26.2}"
IOS_DESTINATION="${DAILVE_IOS_DESTINATION:-platform=iOS Simulator,name=${IOS_SIM_NAME},OS=${IOS_SIM_OS}}"
WATCH_SCHEME="DUNEWatchTests"
WATCH_SIM_NAME="${DUNE_WATCH_SIM_NAME:-Apple Watch Series 10 (46mm)}"
WATCH_SIM_OS="${DUNE_WATCH_SIM_OS:-26.2}"
WATCH_DESTINATION="${DAILVE_WATCH_DESTINATION:-platform=watchOS Simulator,name=${WATCH_SIM_NAME},OS=${WATCH_SIM_OS}}"
DERIVED_DATA_DIR=".deriveddata"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/unit-test.log"
REGENERATE=1
MODE="all"
STREAM_LOGS=0

if [[ "${CI:-}" == "true" ]]; then
    STREAM_LOGS=1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-regen)
            REGENERATE=0
            shift
            ;;
        --ios-only)
            MODE="ios"
            shift
            ;;
        --watch-only)
            MODE="watch"
            shift
            ;;
        --stream-log)
            STREAM_LOGS=1
            shift
            ;;
        --no-stream-log)
            STREAM_LOGS=0
            shift
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen] [--ios-only | --watch-only] [--stream-log | --no-stream-log] [--log-file <path>]"
            exit 2
            ;;
    esac
done

mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
regen_project

resolve_sim_destination() {
    local platform="$1"
    local runtime_prefix="$2"
    local sim_name="$3"
    local sim_os="$4"
    local requested="platform=${platform} Simulator,name=${sim_name},OS=${sim_os}"

    if xcrun simctl list devices available | grep -F "${sim_name}" | grep -F "${sim_os}" >/dev/null 2>&1; then
        echo "$requested"
        return
    fi

    local fallback_id
    fallback_id=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
runtime_prefix = '${runtime_prefix}'
for runtime, devices in data.get('devices', {}).items():
    if runtime_prefix not in runtime:
        continue
    for device in devices:
        if device.get('isAvailable', True):
            print(device['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null) || true

    if [[ -n "${fallback_id}" ]]; then
        echo "platform=${platform} Simulator,id=${fallback_id}"
    else
        echo "$requested"
    fi
}

if [[ "$MODE" != "watch" && -z "${DAILVE_IOS_DESTINATION:-}" ]]; then
    IOS_DESTINATION="$(resolve_sim_destination "iOS" "iOS-${IOS_SIM_OS//./-}" "$IOS_SIM_NAME" "$IOS_SIM_OS")"
fi

if [[ "$MODE" != "ios" && -z "${DAILVE_WATCH_DESTINATION:-}" ]]; then
    WATCH_DESTINATION="$(resolve_sim_destination "watchOS" "watchOS-${WATCH_SIM_OS//./-}" "$WATCH_SIM_NAME" "$WATCH_SIM_OS")"
fi

IOS_LOG_FILE="$LOG_FILE"
WATCH_LOG_FILE="$LOG_FILE"
if [[ "$MODE" == "all" ]]; then
    if [[ "$LOG_FILE" == *.log ]]; then
        WATCH_LOG_FILE="${LOG_FILE%.log}-watch.log"
    else
        WATCH_LOG_FILE="${LOG_FILE}-watch.log"
    fi
fi

run_suite() {
    local suite_name="$1"
    local scheme="$2"
    local destination="$3"
    local only_testing="$4"
    local log_file="$5"
    local test_cmd

    echo "Running ${suite_name} with scheme '$scheme' for destination '$destination'..."

    test_cmd=(xcodebuild test -project "$PROJECT_FILE"
        -scheme "$scheme"
        -destination "$destination"
        -derivedDataPath "$DERIVED_DATA_DIR"
        -only-testing "$only_testing"
        CODE_SIGNING_ALLOWED=NO
        CODE_SIGNING_REQUIRED=NO)

    if [[ "$STREAM_LOGS" -eq 1 ]]; then
        echo "Streaming logs to console and $log_file"
    fi

    set +e
    if [[ "$STREAM_LOGS" -eq 1 ]]; then
        "${test_cmd[@]}" 2>&1 | tee "$log_file"
        local test_exit=${PIPESTATUS[0]}
    else
        "${test_cmd[@]}" >"$log_file" 2>&1
        local test_exit=$?
    fi
    set -e

    if [[ "$test_exit" -ne 0 ]]; then
        echo ""
        echo "${suite_name} failed. Summary:"
        grep -n -E "TEST (SUCCEEDED|FAILED)|error:|failed|Executed" "$log_file" | tail -n 120 || true
        echo ""
        echo "Full log: $log_file"
        exit "$test_exit"
    fi

    echo "${suite_name} passed."
    grep -n -E "TEST (SUCCEEDED|FAILED)|Executed" "$log_file" | tail -n 20 || true
}

if [[ "$MODE" == "ios" || "$MODE" == "all" ]]; then
    run_suite "iOS unit tests" "$IOS_SCHEME" "$IOS_DESTINATION" "DUNETests" "$IOS_LOG_FILE"
fi

if [[ "$MODE" == "watch" || "$MODE" == "all" ]]; then
    run_suite "Watch unit tests" "$WATCH_SCHEME" "$WATCH_DESTINATION" "DUNEWatchTests" "$WATCH_LOG_FILE"
fi
