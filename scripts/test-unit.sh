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
IOS_SIM_OS="${DUNE_SIM_OS:-26.0}"
IOS_DESTINATION="${DAILVE_IOS_DESTINATION:-platform=iOS Simulator,name=${IOS_SIM_NAME},OS=${IOS_SIM_OS}}"
WATCH_SCHEME="DUNEWatchTests"
WATCH_SIM_NAME="${DUNE_WATCH_SIM_NAME:-Apple Watch Series 11 (46mm)}"
WATCH_SIM_OS="${DUNE_WATCH_SIM_OS:-26.2}"
WATCH_DESTINATION="${DAILVE_WATCH_DESTINATION:-platform=watchOS Simulator,name=${WATCH_SIM_NAME},OS=${WATCH_SIM_OS}}"
DERIVED_DATA_DIR="${DAILVE_UNIT_TEST_DERIVED_DATA_DIR:-.deriveddata/unit-tests}"
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
    local minimum_major="$5"
    local requested="platform=${platform} Simulator,name=${sim_name},OS=${sim_os}"
    local available_json
    available_json="$(xcrun simctl list devices available -j 2>/dev/null || true)"

    if [[ -z "${available_json}" ]]; then
        echo "$requested"
        return
    fi

    local fallback_id
    fallback_id=$(PLATFORM="$platform" \
        RUNTIME_PREFIX="$runtime_prefix" \
        SIM_NAME="$sim_name" \
        MINIMUM_MAJOR="$minimum_major" \
        python3 -c "
import json, os, re, sys

platform = os.environ['PLATFORM']
runtime_prefix = os.environ['RUNTIME_PREFIX']
sim_name = os.environ['SIM_NAME']
minimum_major = int(os.environ['MINIMUM_MAJOR'])
data = json.load(sys.stdin)

pattern = re.compile(rf'{re.escape(platform)}-(\\d+)-(\\d+)(?:-(\\d+))?')
candidates = []
for runtime, devices in data.get('devices', {}).items():
    match = pattern.search(runtime)
    if not match:
        continue
    version = tuple(int(part or 0) for part in match.groups())
    for device in devices:
        if not device.get('isAvailable', True):
            continue
        candidates.append({
            'runtime': runtime,
            'version': version,
            'name': device.get('name'),
            'udid': device.get('udid'),
        })

def select(entries):
    if not entries:
        return None
    entries.sort(key=lambda entry: (entry['version'], entry['name'] or ''), reverse=True)
    return entries[0]['udid']

exact = select([
    entry for entry in candidates
    if entry['name'] == sim_name and runtime_prefix in entry['runtime']
])
if exact:
    print(exact)
    sys.exit(0)

same_name_compatible = select([
    entry for entry in candidates
    if entry['name'] == sim_name and entry['version'][0] >= minimum_major
])
if same_name_compatible:
    print(same_name_compatible)
    sys.exit(0)

compatible = select([
    entry for entry in candidates
    if entry['version'][0] >= minimum_major
])
if compatible:
    print(compatible)
    sys.exit(0)

same_runtime = select([
    entry for entry in candidates
    if runtime_prefix in entry['runtime']
])
if same_runtime:
    print(same_runtime)
    sys.exit(0)

any_runtime = select(candidates)
if any_runtime:
    print(any_runtime)
    sys.exit(0)

sys.exit(1)
" <<<"${available_json}" 2>/dev/null) || true

    if [[ -n "${fallback_id}" ]]; then
        echo "platform=${platform} Simulator,id=${fallback_id}"
        return
    fi

    echo "$requested"
}

if [[ "$MODE" != "watch" && -z "${DAILVE_IOS_DESTINATION:-}" ]]; then
    IOS_DESTINATION="$(resolve_sim_destination "iOS" "iOS-${IOS_SIM_OS//./-}" "$IOS_SIM_NAME" "$IOS_SIM_OS" "26")"
fi

if [[ "$MODE" != "ios" && -z "${DAILVE_WATCH_DESTINATION:-}" ]]; then
    WATCH_DESTINATION="$(resolve_sim_destination "watchOS" "watchOS-${WATCH_SIM_OS//./-}" "$WATCH_SIM_NAME" "$WATCH_SIM_OS" "26")"
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
        grep -a -n -E "TEST (SUCCEEDED|FAILED)|error:|failed|Executed" "$log_file" | tail -n 120 || true
        echo ""
        echo "Full log: $log_file"
        exit "$test_exit"
    fi

    echo "${suite_name} passed."
    grep -a -n -E "TEST (SUCCEEDED|FAILED)|Executed" "$log_file" | tail -n 20 || true
}

if [[ "$MODE" == "ios" || "$MODE" == "all" ]]; then
    run_suite "iOS unit tests" "$IOS_SCHEME" "$IOS_DESTINATION" "DUNETests" "$IOS_LOG_FILE"
fi

if [[ "$MODE" == "watch" || "$MODE" == "all" ]]; then
    run_suite "Watch unit tests" "$WATCH_SCHEME" "$WATCH_DESTINATION" "DUNEWatchTests" "$WATCH_LOG_FILE"
fi
