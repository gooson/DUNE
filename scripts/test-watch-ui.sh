#!/bin/bash
# Run DUNEWatchUITests on watchOS Simulator.
# - Regenerates project from xcodegen (unless --no-regen)
# - Boots watch simulator beforehand
# - Runs watch UI tests with DUNEWatchUITests scheme

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
if [[ -z "${DUNE_UI_WATCHDOG_ACTIVE:-}" ]]; then
    WALL_TIMEOUT="${DUNE_UI_TEST_WALL_TIMEOUT:-}"
    WATCH_ACTIVITY_FILE=".xcodebuild/watch-ui-test.log"
    WATCH_ARGS=("$@")
    for ((arg_index=0; arg_index<${#WATCH_ARGS[@]}; arg_index++)); do
        if [[ "${WATCH_ARGS[arg_index]}" == "--log-file" && $((arg_index + 1)) -lt ${#WATCH_ARGS[@]} ]]; then
            WATCH_ACTIVITY_FILE="${WATCH_ARGS[arg_index + 1]}"
        fi
    done
    if [[ -z "$WALL_TIMEOUT" ]]; then
        WALL_TIMEOUT=10800
        for arg in "$@"; do
            if [[ "$arg" == "--smoke" || "$arg" == "--only-testing" ]]; then
                WALL_TIMEOUT=1800
                break
            fi
        done
    fi
    exec python3 "$ROOT_DIR/scripts/lib/command-deadline.py" \
        --seconds "$WALL_TIMEOUT" --idle-seconds "${DUNE_UI_TEST_IDLE_TIMEOUT:-900}" \
        --activity-file "$WATCH_ACTIVITY_FILE" -- "$ROOT_DIR/scripts/test-watch-ui.sh" "$@"
fi
if [[ -n "${DUNE_SIM_TEST_LOCK_FD:-}" ]]; then
    python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" --verify
else
    exec python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" -- "$ROOT_DIR/scripts/test-watch-ui.sh" "$@"
fi
source "$ROOT_DIR/scripts/lib/regen-project.sh"
source "$ROOT_DIR/scripts/lib/simulator-boot.sh"
source "$ROOT_DIR/scripts/lib/simulator-worktree.sh"
TEST_SUMMARY="$ROOT_DIR/scripts/lib/test-log-summary.py"
TEST_VERIFY="$ROOT_DIR/scripts/lib/verify-ui-test-log.py"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNEWatchUITests"
WATCH_SIM_NAME="${DUNE_WATCH_SIM_NAME:-Apple Watch Series 10 (46mm)}"
WATCH_SIM_OS="${DUNE_WATCH_SIM_OS:-27.0}"
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
        --cleanup-simulators)
            cleanup_worktree_simulators --owned
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen] [--stream-log | --no-stream-log] [--log-file <path>] [--skip-testing <target>] [--only-testing <target>] [--test-plan <name>] [--smoke] [--cleanup-simulators]"
            exit 2
            ;;
    esac
done

# The simulator lock is held here. Clear prior evidence before any preflight
# can fail and leave a stale successful result for this log path.
RESULT_FILE="${LOG_FILE}.result.json"
rm -f "$RESULT_FILE"
HOST_STATE_FILE="${LOG_FILE}.host.json"
rm -f "$HOST_STATE_FILE"
python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 5 -- \
    python3 "$ROOT_DIR/scripts/lib/ui-host-state.py" \
    --runner watch --output "$HOST_STATE_FILE" || \
    echo "Host state context unavailable; continuing watch UI test preflight." >&2

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

for target in ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"} ${SKIP_TESTING[@]+"${SKIP_TESTING[@]}"}; do
    if [[ ! "$target" =~ ^DUNEWatchUITests(/[A-Za-z_][A-Za-z_0-9]*){0,2}$ ]]; then
        echo "Invalid watch UI test selector: $target" >&2
        exit 2
    fi
done
PLAN_FILE="DUNEWatchUITests/${TEST_PLAN}.xctestplan"
if [[ ! -f "$PLAN_FILE" ]]; then
    echo "Unknown watch UI test plan: $TEST_PLAN" >&2
    exit 2
fi
if [[ "${#ONLY_TESTING[@]}" -gt 0 ]]; then
    PLAN_CHECK=(python3 "$TEST_VERIFY" --check-plan "$PLAN_FILE" --target DUNEWatchUITests)
    for target in "${ONLY_TESTING[@]}"; do
        PLAN_CHECK+=(--only "$target")
    done
    "${PLAN_CHECK[@]}"
fi

mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
regen_project

echo "Ensuring watch simulator '$WATCH_SIM_NAME' is booted..."
DEVICE_INFO=$(_simctl_bounded 30 list devices available -j \
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
    if not os_version or int(os_version.split('.')[0]) < 27:
        continue
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

sys.exit(0)
" 2>/dev/null) || {
    echo "Error: Could not query available Watch simulators; test execution stopped." >&2
    exit 2
}

RESOLVED_WATCH_SIM_NAME="$WATCH_SIM_NAME"
RESOLVED_WATCH_SIM_OS="$WATCH_SIM_OS"

if [[ -n "$DEVICE_INFO" ]]; then
    IFS=$'\t' read -r DEVICE_UDID RESOLVED_WATCH_SIM_NAME RESOLVED_WATCH_SIM_OS <<< "$DEVICE_INFO"
    reset_worktree_simulator "$RESOLVED_WATCH_SIM_NAME"
    DEVICE_UDID=$(ensure_worktree_simulator "$DEVICE_UDID" "$RESOLVED_WATCH_SIM_NAME")
    DESTINATION="id=${DEVICE_UDID}"
    wait_for_simulator_boot "$DEVICE_UDID" "watchOS"
else
    echo "Error: No eligible Watch simulator '$WATCH_SIM_NAME' (OS $WATCH_SIM_OS); test execution stopped." >&2
    exit 2
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

VERIFY_CMD=(python3 "$TEST_VERIFY" --log "$LOG_FILE" --target DUNEWatchUITests --result-json "$RESULT_FILE")
for ((i=0; i<${#TEST_CMD[@]}; i++)); do
    case "${TEST_CMD[i]}" in
        -only-testing) VERIFY_CMD+=(--only "${TEST_CMD[i+1]}") ;;
        -skip-testing) VERIFY_CMD+=(--skip "${TEST_CMD[i+1]}") ;;
    esac
done

if [[ "$STREAM_LOGS" -eq 1 ]]; then
    echo "Streaming logs to console and $LOG_FILE"
fi

mkdir -p "$(dirname "$LOG_FILE")"
set +e
if [[ "$STREAM_LOGS" -eq 1 ]]; then
    "${TEST_CMD[@]}" 2>&1 | tee "$LOG_FILE"
    TEST_EXIT=${PIPESTATUS[0]}
else
    "${TEST_CMD[@]}" >"$LOG_FILE" 2>&1
    TEST_EXIT=$?
fi
set -e

if ! python3 "$TEST_SUMMARY" "$LOG_FILE" "$TEST_EXIT" "Watch UI tests"; then
    echo "Watch UI tests: summary unavailable (xcodebuild exit ${TEST_EXIT})"
    echo "Full log: $LOG_FILE"
fi
"${VERIFY_CMD[@]}" --exit-status "$TEST_EXIT" || {
    if [[ "$TEST_EXIT" -ne 0 ]]; then exit "$TEST_EXIT"; fi
    exit 1
}
exit "$TEST_EXIT"
