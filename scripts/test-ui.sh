#!/bin/bash
# Run DUNEUITests on iOS Simulator.
# - Regenerates project from xcodegen (unless --no-regen)
# - Boots simulator beforehand (UI tests require a running simulator)
# - Runs UI tests with DUNE scheme (defaults to -only-testing DUNEUITests)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"
source "$ROOT_DIR/scripts/lib/simulator-boot.sh"
source "$ROOT_DIR/scripts/lib/simulator-worktree.sh"
TEST_SUMMARY="$ROOT_DIR/scripts/lib/test-log-summary.py"
TEST_VERIFY="$ROOT_DIR/scripts/lib/verify-ui-test-log.py"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNEUITests"
SIMULATOR_NAME="${DAILVE_IOS_SIMULATOR:-iPhone 17}"
SIMULATOR_OS="${DAILVE_IOS_OS:-26.2}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"
DERIVED_DATA_DIR="${DAILVE_UI_TEST_DERIVED_DATA_DIR:-.deriveddata/ui-tests}"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/ui-test.log"
BUNDLE_ID="${DAILVE_IOS_BUNDLE_ID:-com.raftel.dailve}"
REGENERATE=1
SKIP_TESTING=()
ONLY_TESTING=()
TEST_PLAN=""
STREAM_LOGS=0
SMOKE_MODE=0
DRY_RUN=0

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
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --cleanup-simulators)
            cleanup_worktree_simulators --current
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen] [--stream-log | --no-stream-log] [--log-file <path>] [--skip-testing <target>] [--only-testing <target>] [--test-plan <name>] [--smoke] [--dry-run] [--cleanup-simulators]"
            exit 2
            ;;
    esac
done

resolve_test_plan() {
    local requested_plan="$1"

    if [[ -n "$requested_plan" ]]; then
        case "$requested_plan" in
            UITests-CI)
                echo "DUNEUITests-PR"
                return
                ;;
            *)
                echo "$requested_plan"
                return
                ;;
        esac
    fi

    if [[ "$SMOKE_MODE" -eq 1 && "${#ONLY_TESTING[@]}" -eq 0 ]]; then
        echo "DUNEUITests-PR"
    else
        echo "DUNEUITests-Full"
    fi
}

TEST_PLAN="$(resolve_test_plan "$TEST_PLAN")"

for target in ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"} ${SKIP_TESTING[@]+"${SKIP_TESTING[@]}"}; do
    if [[ ! "$target" =~ ^DUNEUITests(/[A-Za-z_][A-Za-z_0-9]*){0,2}$ ]]; then
        echo "Invalid UI test selector: $target" >&2
        exit 2
    fi
done

PLAN_FILE="DUNEUITests/${TEST_PLAN}.xctestplan"
if [[ ! -f "$PLAN_FILE" ]]; then
    echo "Unknown UI test plan: $TEST_PLAN" >&2
    exit 2
fi
if [[ "${#ONLY_TESTING[@]}" -gt 0 ]]; then
    PLAN_CHECK=(python3 "$TEST_VERIFY" --check-plan "$PLAN_FILE")
    for target in ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"}; do
        PLAN_CHECK+=(--only "$target")
    done
    "${PLAN_CHECK[@]}"
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
    regen_project
fi

# Boot simulator if not already booted (UI tests need it)
if [[ "$DRY_RUN" -eq 0 ]]; then
echo "Ensuring simulator '$SIMULATOR_NAME' is booted..."
DEVICE_INFO=$(xcrun simctl list devices available -j \
    | python3 -c "
import json, re, sys
requested_name = '${SIMULATOR_NAME}'
requested_os = '${SIMULATOR_OS}'
data = json.load(sys.stdin)
candidates = []

def parse_os(runtime: str) -> str:
    match = re.search(r'iOS-(\d+)-(\d+)', runtime)
    return f'{match.group(1)}.{match.group(2)}' if match else ''

for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime:
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
    if candidate[0].startswith('iPhone'):
        emit(candidate)

if candidates:
    emit(candidates[0])

sys.exit(1)
" 2>/dev/null) || true

RESOLVED_SIMULATOR_NAME="$SIMULATOR_NAME"
RESOLVED_SIMULATOR_OS="$SIMULATOR_OS"

if [[ -n "$DEVICE_INFO" ]]; then
    IFS=$'\t' read -r DEVICE_UDID RESOLVED_SIMULATOR_NAME RESOLVED_SIMULATOR_OS <<< "$DEVICE_INFO"
    DEVICE_UDID=$(ensure_worktree_simulator "$DEVICE_UDID" "$RESOLVED_SIMULATOR_NAME")
    DESTINATION="id=${DEVICE_UDID}"
    wait_for_simulator_boot "$DEVICE_UDID" "iOS"
    xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
else
    echo "Warning: Could not find simulator '$SIMULATOR_NAME' (OS $SIMULATOR_OS). xcodebuild will attempt to boot one."
fi
fi

echo "Running UI tests with scheme '$SCHEME' for destination '$DESTINATION'..."

# Build test command
TEST_CMD=(xcodebuild test -project "$PROJECT_FILE"
    -scheme "$SCHEME"
    -destination "$DESTINATION"
    -derivedDataPath "$DERIVED_DATA_DIR"
    -parallel-testing-enabled NO
    -test-timeouts-enabled YES
    -default-test-execution-time-allowance 300
    -maximum-test-execution-time-allowance 600
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO)

TEST_CMD+=(-testPlan "$TEST_PLAN")
echo "Using test plan: $TEST_PLAN"

if [[ "$SMOKE_MODE" -eq 1 ]]; then
    SMOKE_ONLY=(
        DUNEUITests/DashboardSmokeTests
        DUNEUITests/ActivitySmokeTests
        DUNEUITests/WellnessSmokeTests/testWellnessTabLoads
        DUNEUITests/LifeSmokeTests
    )
    SMOKE_SKIP=(
        DUNEUITests/ActivitySmokeTests/testPullToRefreshShowsWaveIndicator
        DUNEUITests/LifeSmokeTests/testWeeklyFrequencyShowsStepper
        DUNEUITests/WellnessSmokeTests/testBodyFormSaveEnablesAfterInput
        DUNEUITests/WellnessSmokeTests/testInjuryRecoveredToggleShowsEndDate
        DUNEUITests/SettingsSmokeTests/testAppearanceSectionExists
        DUNEUITests/SettingsSmokeTests/testDataPrivacySectionExists
        DUNEUITests/SettingsSmokeTests/testAboutSectionExists
        DUNEUITests/SettingsSmokeTests/testPreferredExercisesLinkExists
        DUNEUITests/SettingsSmokeTests/testNavigateToPreferredExercises
        DUNEUITests/SettingsSmokeTests/testWhatsNewLinkExists
        DUNEUITests/SettingsSmokeTests/testNavigateToWhatsNew
        DUNEUITests/SettingsSmokeTests/testWhatsNewNotificationsDetailShowsArtwork
        DUNEUITests/SettingsSmokeTests/testWhatsNewSleepDebtDetailExists
        DUNEUITests/SettingsSmokeTests/testWhatsNewWidgetDetailExists
        DUNEUITests/SettingsSmokeTests/testWhatsNewMuscleMapDetailExists
    )
    for target in "${SMOKE_ONLY[@]}"; do
        TEST_CMD+=(-only-testing "$target")
    done
    for skip in "${SMOKE_SKIP[@]}"; do
        overridden=0
        for target in ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"}; do
            if [[ "$skip" == "$target" || "$skip" == "$target/"* ]]; then
                overridden=1
                break
            fi
        done
        if [[ "$overridden" -eq 0 ]]; then
            TEST_CMD+=(-skip-testing "$skip")
        fi
    done
    echo "Smoke mode enabled: running iOS smoke suite"
fi

if [[ "${#ONLY_TESTING[@]}" -gt 0 ]]; then
    for target in ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"}; do
        TEST_CMD+=(-only-testing "$target")
        echo "Only testing: $target"
    done
elif [[ "$SMOKE_MODE" -eq 0 ]]; then
    TEST_CMD+=(-only-testing DUNEUITests)
fi

if [[ "${#SKIP_TESTING[@]}" -gt 0 ]]; then
    for skip in ${SKIP_TESTING[@]+"${SKIP_TESTING[@]}"}; do
        TEST_CMD+=(-skip-testing "$skip")
        echo "Skipping: $skip"
    done
fi

# Verify the exact selectors and skips passed to xcodebuild, including smoke defaults.
VERIFY_CMD=(python3 "$TEST_VERIFY" --log "$LOG_FILE")
for ((i=0; i<${#TEST_CMD[@]}; i++)); do
    case "${TEST_CMD[i]}" in
        -only-testing)
            VERIFY_CMD+=(--only "${TEST_CMD[i+1]}")
            ;;
        -skip-testing)
            VERIFY_CMD+=(--skip "${TEST_CMD[i+1]}")
            ;;
    esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'DRY_RUN_COMMAND='
    printf '%q ' "${TEST_CMD[@]}"
    printf '\n'
    printf 'DRY_RUN_VERIFY_COMMAND='
    printf '%q ' "${VERIFY_CMD[@]}"
    printf '\n'
    exit 0
fi

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

if ! python3 "$TEST_SUMMARY" "$LOG_FILE" "$TEST_EXIT" "UI tests"; then
    echo "UI tests: summary unavailable (xcodebuild exit ${TEST_EXIT})"
    echo "Full log: $LOG_FILE"
fi
if [[ "$TEST_EXIT" -eq 0 ]]; then
    "${VERIFY_CMD[@]}" || exit 1
fi
exit "$TEST_EXIT"
