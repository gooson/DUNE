#!/bin/bash
# Run DUNEUITests on iOS Simulator.
# - Regenerates project from xcodegen (unless --no-regen)
# - Boots simulator beforehand (UI tests require a running simulator)
# - Runs UI tests with DUNE scheme (defaults to -only-testing DUNEUITests)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"

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

    if [[ "$SMOKE_MODE" -eq 1 ]]; then
        echo "DUNEUITests-PR"
    else
        echo "DUNEUITests-Full"
    fi
}

TEST_PLAN="$(resolve_test_plan "$TEST_PLAN")"

mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
regen_project

# Boot simulator if not already booted (UI tests need it)
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
    DESTINATION="id=${DEVICE_UDID}"
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true

    # Wait for simulator to reach Booted state (timeout 120s)
    BOOT_TIMEOUT=120
    BOOT_ELAPSED=0
    while [[ "$BOOT_ELAPSED" -lt "$BOOT_TIMEOUT" ]]; do
        BOOT_STATE=$(xcrun simctl list devices | grep "$DEVICE_UDID" | grep -o "Booted" || true)
        if [[ "$BOOT_STATE" == "Booted" ]]; then
            break
        fi
        sleep 2
        BOOT_ELAPSED=$((BOOT_ELAPSED + 2))
    done

    if [[ "$BOOT_ELAPSED" -ge "$BOOT_TIMEOUT" ]]; then
        echo "ERROR: Simulator failed to boot within ${BOOT_TIMEOUT}s."
        exit 1
    fi

    xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "Simulator booted: $RESOLVED_SIMULATOR_NAME ($RESOLVED_SIMULATOR_OS) [$DEVICE_UDID] (${BOOT_ELAPSED}s)"
else
    echo "Warning: Could not find simulator '$SIMULATOR_NAME' (OS $SIMULATOR_OS). xcodebuild will attempt to boot one."
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

if [[ "${#ONLY_TESTING[@]}" -gt 0 ]]; then
    for target in "${ONLY_TESTING[@]}"; do
        TEST_CMD+=(-only-testing "$target")
        echo "Only testing: $target"
    done
else
    if [[ "$SMOKE_MODE" -eq 1 ]]; then
        TEST_CMD+=(-only-testing DUNEUITests/DashboardSmokeTests)
        TEST_CMD+=(-only-testing DUNEUITests/ActivitySmokeTests)
        TEST_CMD+=(-only-testing DUNEUITests/WellnessSmokeTests/testWellnessTabLoads)
        TEST_CMD+=(-only-testing DUNEUITests/LifeSmokeTests)
        TEST_CMD+=(-skip-testing DUNEUITests/ActivitySmokeTests/testPullToRefreshShowsWaveIndicator)
        TEST_CMD+=(-skip-testing DUNEUITests/LifeSmokeTests/testWeeklyFrequencyShowsStepper)
        TEST_CMD+=(-skip-testing DUNEUITests/WellnessSmokeTests/testBodyFormSaveEnablesAfterInput)
        TEST_CMD+=(-skip-testing DUNEUITests/WellnessSmokeTests/testInjuryRecoveredToggleShowsEndDate)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testAppearanceSectionExists)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testDataPrivacySectionExists)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testAboutSectionExists)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testPreferredExercisesLinkExists)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testNavigateToPreferredExercises)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testWhatsNewLinkExists)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testNavigateToWhatsNew)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testWhatsNewNotificationsDetailShowsArtwork)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testWhatsNewSleepDebtDetailExists)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testWhatsNewWidgetDetailExists)
        TEST_CMD+=(-skip-testing DUNEUITests/SettingsSmokeTests/testWhatsNewMuscleMapDetailExists)
        echo "Smoke mode enabled: running iOS smoke suite only"
    else
        TEST_CMD+=(-only-testing DUNEUITests)
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
    echo "UI tests failed. Summary:"
    grep -a -n -E "TEST (SUCCEEDED|FAILED)|error:|failed|Executed" "$LOG_FILE" | tail -n 120 || true
    echo ""
    echo "Full log: $LOG_FILE"
    exit "$TEST_EXIT"
fi

echo "UI tests passed."
grep -a -n -E "TEST (SUCCEEDED|FAILED)|Executed" "$LOG_FILE" | tail -n 20 || true
