#!/bin/bash
# Run unit tests on iOS + watchOS simulators.
# - Regenerates project from xcodegen (unless --no-regen)
# - Runs DUNETests and DUNEWatchTests sequentially
# - Prints concise failure summary per suite

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ORIGINAL_ARGS=("$@")
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"
source "$ROOT_DIR/scripts/lib/simulator-boot.sh"
source "$ROOT_DIR/scripts/lib/simulator-worktree.sh"
source "$ROOT_DIR/scripts/lib/xcodebuild-resources.sh"
configure_xcodebuild_resources unit
TEST_SUMMARY="$ROOT_DIR/scripts/lib/test-log-summary.py"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
IOS_SCHEME="DUNETests"
IOS_SIM_NAME="${DUNE_SIM_NAME:-iPhone 17}"
IOS_SIM_OS="${DUNE_SIM_OS:-27.0}"
IOS_DESTINATION="${DAILVE_IOS_DESTINATION:-platform=iOS Simulator,name=${IOS_SIM_NAME},OS=${IOS_SIM_OS}}"
WATCH_SCHEME="DUNEWatchTests"
WATCH_SIM_NAME="${DUNE_WATCH_SIM_NAME:-Apple Watch Series 11 (46mm)}"
WATCH_SIM_OS="${DUNE_WATCH_SIM_OS:-27.0}"
WATCH_DESTINATION="${DAILVE_WATCH_DESTINATION:-platform=watchOS Simulator,name=${WATCH_SIM_NAME},OS=${WATCH_SIM_OS}}"
DERIVED_DATA_DIR="${DAILVE_UNIT_TEST_DERIVED_DATA_DIR:-.deriveddata/unit-tests}"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/unit-test.log"
REGENERATE=1
MODE="all"
STREAM_LOGS=0
DRY_RUN=0
IOS_ONLY_TESTING=()
WATCH_ONLY_TESTING=()
ONLY_TESTING=()

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
            if [[ "$MODE" == "watch" ]]; then
                echo "--ios-only and --watch-only cannot be combined" >&2
                exit 2
            fi
            MODE="ios"
            shift
            ;;
        --watch-only)
            if [[ "$MODE" == "ios" ]]; then
                echo "--ios-only and --watch-only cannot be combined" >&2
                exit 2
            fi
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
            if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
                echo "--log-file requires a path" >&2
                exit 2
            fi
            LOG_FILE="$2"
            shift 2
            ;;
        --only-testing)
            if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
                echo "--only-testing requires a target-qualified selector" >&2
                exit 2
            fi
            ONLY_TESTING+=("$2")
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --cleanup-simulators)
            CLEANUP_MODE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen] [--ios-only | --watch-only] [--stream-log | --no-stream-log] [--log-file <path>] [--only-testing <target/class[/method]> ...] [--dry-run] [--cleanup-simulators]"
            exit 2
            ;;
    esac
done

if [[ "${CLEANUP_MODE:-0}" -eq 1 && ( "$DRY_RUN" -eq 1 || ${#ONLY_TESTING[@]} -gt 0 ) ]]; then
    echo "--cleanup-simulators cannot be combined with --dry-run or --only-testing" >&2
    exit 2
fi

for selector in ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"}; do
    if [[ ! "$selector" =~ ^(DUNETests|DUNEWatchTests)/[A-Za-z_][A-Za-z_0-9]*(/[A-Za-z_][A-Za-z_0-9]*)?$ ]]; then
        echo "Invalid unit test selector: $selector" >&2
        exit 2
    fi
    case "$selector" in
        DUNETests/*)
            if [[ "$MODE" == "watch" ]]; then
                echo "iOS selector is incompatible with --watch-only: $selector" >&2
                exit 2
            fi
            IOS_ONLY_TESTING+=("$selector")
            ;;
        DUNEWatchTests/*)
            if [[ "$MODE" == "ios" ]]; then
                echo "Watch selector is incompatible with --ios-only: $selector" >&2
                exit 2
            fi
            WATCH_ONLY_TESTING+=("$selector")
            ;;
    esac
done

if [[ ${#ONLY_TESTING[@]} -gt 0 ]]; then
    python3 "$ROOT_DIR/scripts/lib/validate-unit-test-selectors.py" "${ONLY_TESTING[@]}"
fi

RUN_IOS=0
RUN_WATCH=0
if [[ ${#ONLY_TESTING[@]} -eq 0 ]]; then
    [[ "$MODE" == "watch" ]] || RUN_IOS=1
    [[ "$MODE" == "ios" ]] || RUN_WATCH=1
else
    [[ ${#IOS_ONLY_TESTING[@]} -eq 0 ]] || RUN_IOS=1
    [[ ${#WATCH_ONLY_TESTING[@]} -eq 0 ]] || RUN_WATCH=1
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ -n "${DUNE_SIM_TEST_LOCK_FD:-}" ]]; then
        python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" --verify
    else
        exec python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" -- "$ROOT_DIR/scripts/test-unit.sh" ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}
    fi
    if [[ "${CLEANUP_MODE:-0}" -eq 1 ]]; then
        cleanup_worktree_simulators --owned
        exit 0
    fi
    mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
    regen_project
fi

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
    if version[0] < minimum_major:
        continue
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

same_name = select([
    entry for entry in candidates
    if entry['name'] == sim_name
])
if same_name:
    print(same_name)
    sys.exit(0)

fallback = select(candidates)
if fallback:
    print(fallback)
    sys.exit(0)

sys.exit(1)
" <<<"${available_json}" 2>/dev/null) || true

    if [[ -n "${fallback_id}" ]]; then
        echo "platform=${platform} Simulator,id=${fallback_id}"
        return
    fi

    echo "$requested"
}

preboot_from_destination() {
    local destination="$1"
    local label="$2"
    local udid
    udid=$(echo "$destination" | grep -oE 'id=[0-9A-Fa-f-]+' | cut -d= -f2) || true
    if [[ -z "$udid" ]]; then
        echo "Warning: Could not extract UDID from destination '$destination'. Skipping pre-boot."
        return
    fi
    wait_for_simulator_boot "$udid" "$label"
}

IOS_LOG_FILE="$LOG_FILE"
WATCH_LOG_FILE="$LOG_FILE"
if [[ "$RUN_IOS" -eq 1 && "$RUN_WATCH" -eq 1 ]]; then
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
    local log_file="$4"
    shift 4
    local selectors=("$@")
    local test_cmd

    echo "Running ${suite_name} with scheme '$scheme' for destination '$destination'..."

    test_cmd=(xcodebuild test -project "$PROJECT_FILE"
        -scheme "$scheme"
        -destination "$destination"
        -derivedDataPath "$DERIVED_DATA_DIR"
        ${XCODEBUILD_RESOURCE_ARGS[@]+"${XCODEBUILD_RESOURCE_ARGS[@]}"})
    for selector in "${selectors[@]}"; do
        test_cmd+=(-only-testing "$selector")
    done
    test_cmd+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)

    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf 'DRY_RUN_COMMAND='
        printf '%q ' "${test_cmd[@]}"
        printf '\n'
        return
    fi

    mkdir -p "$(dirname "$log_file")"

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

    if ! python3 "$TEST_SUMMARY" "$log_file" "$test_exit" "$suite_name"; then
        echo "${suite_name}: summary unavailable (xcodebuild exit ${test_exit})"
        echo "Full log: $log_file"
    fi
    if [[ "$test_exit" -ne 0 ]]; then
        exit "$test_exit"
    fi
    if [[ ${#ONLY_TESTING[@]} -gt 0 ]] && ! grep -Eq 'Executed [1-9][0-9]* tests?, with|Test run with [1-9][0-9]* tests?( in [1-9][0-9]* suites?)? (passed|failed)' "$log_file"; then
        echo "${suite_name}: selected tests have no positive execution count in $log_file" >&2
        exit 1
    fi
}

if [[ "$RUN_IOS" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
        if [[ -z "${DAILVE_IOS_DESTINATION:-}" ]]; then
            IOS_DESTINATION="$(resolve_sim_destination "iOS" "iOS-${IOS_SIM_OS//./-}" "$IOS_SIM_NAME" "$IOS_SIM_OS" "27")"
        fi
        IOS_DESTINATION=$(apply_worktree_destination "$IOS_DESTINATION" "$IOS_SIM_NAME" "iOS")
        preboot_from_destination "$IOS_DESTINATION" "iOS"
    fi
    if [[ ${#ONLY_TESTING[@]} -eq 0 ]]; then
        IOS_ONLY_TESTING=(DUNETests)
    fi
    run_suite "iOS unit tests" "$IOS_SCHEME" "$IOS_DESTINATION" "$IOS_LOG_FILE" "${IOS_ONLY_TESTING[@]}"
fi

if [[ "$RUN_WATCH" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
        if [[ -z "${DAILVE_WATCH_DESTINATION:-}" ]]; then
            WATCH_DESTINATION="$(resolve_sim_destination "watchOS" "watchOS-${WATCH_SIM_OS//./-}" "$WATCH_SIM_NAME" "$WATCH_SIM_OS" "27")"
        fi
        WATCH_DESTINATION=$(apply_worktree_destination "$WATCH_DESTINATION" "$WATCH_SIM_NAME" "watchOS")
        preboot_from_destination "$WATCH_DESTINATION" "watchOS"
    fi
    if [[ ${#ONLY_TESTING[@]} -eq 0 ]]; then
        WATCH_ONLY_TESTING=(DUNEWatchTests)
    fi
    run_suite "Watch unit tests" "$WATCH_SCHEME" "$WATCH_DESTINATION" "$WATCH_LOG_FILE" "${WATCH_ONLY_TESTING[@]}"
fi
