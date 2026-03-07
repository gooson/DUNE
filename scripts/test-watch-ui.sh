#!/bin/bash
# Run DUNEWatchUITests on watchOS Simulator.
# - Regenerates project from xcodegen (unless --no-regen)
# - Boots watch simulator beforehand
# - Runs watch UI tests with DUNEWatchUITests scheme

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNEWatchUITests"
WATCH_SIM_NAME="${DUNE_WATCH_SIM_NAME:-Apple Watch Series 10 (46mm)}"
WATCH_SIM_OS="${DUNE_WATCH_SIM_OS:-26.2}"
DESTINATION="platform=watchOS Simulator,name=${WATCH_SIM_NAME},OS=${WATCH_SIM_OS}"
DERIVED_DATA_DIR="${DAILVE_WATCH_UI_TEST_DERIVED_DATA_DIR:-.deriveddata/watch-ui-tests}"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/watch-ui-test.log"
REGENERATE=1
SKIP_TESTING=()
ONLY_TESTING=()
TEST_PLAN=""
STREAM_LOGS=0
SMOKE_MODE=0

if [[ "${CI:-}" == "true" ]]; then
    STREAM_LOGS=1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-regen)
            REGENERATE=0
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
        --skip-testing)
            SKIP_TESTING+=("$2")
            shift 2
            ;;
        --only-testing)
            ONLY_TESTING+=("$2")
            shift 2
            ;;
        --test-plan)
            TEST_PLAN="$2"
            shift 2
            ;;
        --smoke)
            SMOKE_MODE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen] [--stream-log | --no-stream-log] [--log-file <path>] [--skip-testing <target>] [--only-testing <target>] [--test-plan <name>] [--smoke]"
            exit 2
            ;;
    esac
done

resolve_test_plan() {
    local requested_plan="$1"

    if [[ -n "$requested_plan" ]]; then
        case "$requested_plan" in
            WatchUITests-CI)
                echo "DUNEWatchUITests-PR"
                return
                ;;
            *)
                echo "$requested_plan"
                return
                ;;
        esac
    fi

    if [[ "$SMOKE_MODE" -eq 1 ]]; then
        echo "DUNEWatchUITests-PR"
    else
        echo "DUNEWatchUITests-Full"
    fi
}

TEST_PLAN="$(resolve_test_plan "$TEST_PLAN")"

mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
regen_project

echo "Ensuring watch simulator '$WATCH_SIM_NAME' is booted..."
DEVICE_INFO=$(xcrun simctl list devices available -j \
    | python3 -c "
import json, re, sys
requested_name = '${WATCH_SIM_NAME}'
requested_os = '${WATCH_SIM_OS}'
data = json.load(sys.stdin)
candidates = []

def parse_os(runtime: str) -> str:
    match = re.search(r'watchOS-(\d+)-(\d+)', runtime)
    return f'{match.group(1)}.{match.group(2)}' if match else ''

for runtime, devices in data['devices'].items():
    if 'watchOS' not in runtime:
        continue
    os_version = parse_os(runtime)
    for device in devices:
        if not device.get('isAvailable', True):
            continue
        candidates.append((device['name'], os_version, device['udid']))

def emit(choice):
    name, os_version, udid = choice
    print('\\t'.join([udid, name, os_version]))
    sys.exit(0)

for candidate in candidates:
    if candidate[0] == requested_name and candidate[1] == requested_os:
        emit(candidate)

for candidate in candidates:
    if candidate[0] == requested_name:
        emit(candidate)

for candidate in candidates:
    if candidate[0].startswith('Apple Watch'):
        emit(candidate)

if candidates:
    emit(candidates[0])

sys.exit(1)
" 2>/dev/null) || true

RESOLVED_WATCH_SIM_NAME="$WATCH_SIM_NAME"
RESOLVED_WATCH_SIM_OS="$WATCH_SIM_OS"

if [[ -n "$DEVICE_INFO" ]]; then
    IFS=$'\t' read -r DEVICE_UDID RESOLVED_WATCH_SIM_NAME RESOLVED_WATCH_SIM_OS <<< "$DEVICE_INFO"
    DESTINATION="id=${DEVICE_UDID}"
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
    echo "Watch simulator booted: $RESOLVED_WATCH_SIM_NAME ($RESOLVED_WATCH_SIM_OS) [$DEVICE_UDID]"
else
    echo "Warning: Could not find watch simulator '$WATCH_SIM_NAME' (OS $WATCH_SIM_OS). xcodebuild will attempt to boot one."
fi

echo "Running watch UI tests with scheme '$SCHEME' for destination '$DESTINATION'..."

TEST_CMD=(xcodebuild test -project "$PROJECT_FILE"
    -scheme "$SCHEME"
    -destination "$DESTINATION"
    -derivedDataPath "$DERIVED_DATA_DIR"
    -parallel-testing-enabled NO
    -test-timeouts-enabled YES
    -default-test-execution-time-allowance 120
    -maximum-test-execution-time-allowance 300
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO)

TEST_CMD+=(-testPlan "$TEST_PLAN")
echo "Using test plan: $TEST_PLAN"

if [[ "${#ONLY_TESTING[@]}" -gt 0 ]]; then
    for target in "${ONLY_TESTING[@]}"; do
        TEST_CMD+=(-only-testing "$target")
        echo "Only testing: $target"
    done
else
    if [[ "$SMOKE_MODE" -eq 1 ]]; then
        TEST_CMD+=(-only-testing DUNEWatchUITests/WatchHomeSmokeTests)
        TEST_CMD+=(-only-testing DUNEWatchUITests/WatchWorkoutStartSmokeTests)
        echo "Smoke mode enabled: running watch smoke suite only"
    else
        TEST_CMD+=(-only-testing DUNEWatchUITests)
    fi
fi

if [[ "${#SKIP_TESTING[@]}" -gt 0 ]]; then
    for skip in "${SKIP_TESTING[@]}"; do
        TEST_CMD+=(-skip-testing "$skip")
        echo "Skipping: $skip"
    done
fi

if [[ "$STREAM_LOGS" -eq 1 ]]; then
    echo "Streaming logs to console and $LOG_FILE"
fi

set +e
if [[ "$STREAM_LOGS" -eq 1 ]]; then
    "${TEST_CMD[@]}" 2>&1 | tee "$LOG_FILE"
    TEST_EXIT=${PIPESTATUS[0]}
else
    "${TEST_CMD[@]}" >"$LOG_FILE" 2>&1
    TEST_EXIT=$?
fi
set -e

if [[ "$TEST_EXIT" -ne 0 ]]; then
    echo ""
    echo "Watch UI tests failed. Summary:"
    grep -a -n -E "TEST (SUCCEEDED|FAILED)|error:|failed|Executed" "$LOG_FILE" | tail -n 120 || true
    echo ""
    echo "Full log: $LOG_FILE"
    exit "$TEST_EXIT"
fi

echo "Watch UI tests passed."
grep -a -n -E "TEST (SUCCEEDED|FAILED)|Executed" "$LOG_FILE" | tail -n 20 || true
