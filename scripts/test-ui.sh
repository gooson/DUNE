#!/bin/bash
# Run DUNEUITests on iOS Simulator.
# - Regenerates project from xcodegen (unless --no-regen)
# - Boots simulator beforehand (UI tests require a running simulator)
# - Runs UI tests with DUNE scheme, only-testing DUNEUITests

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNE"
SIMULATOR_NAME="${DAILVE_IOS_SIMULATOR:-iPhone 17}"
SIMULATOR_OS="${DAILVE_IOS_OS:-26.2}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"
DERIVED_DATA_DIR=".deriveddata"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/ui-test.log"
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

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required. Install with: brew install xcodegen"
    exit 1
fi

if [[ "$REGENERATE" -eq 1 || ! -d "$PROJECT_FILE" ]]; then
    echo "Generating Xcode project from $PROJECT_SPEC..."
    xcodegen generate --spec "$PROJECT_SPEC" >/tmp/dune-xcodegen.log 2>&1

    PBXPROJ="$PROJECT_FILE/project.pbxproj"
    sed -i '' 's/objectVersion = 77;/objectVersion = 90;/' "$PBXPROJ"
    sed -i '' 's/compatibilityVersion = "Xcode 14.0";/compatibilityVersion = "Xcode 16.3";/' "$PBXPROJ"
fi

# Boot simulator if not already booted (UI tests need it)
echo "Ensuring simulator '$SIMULATOR_NAME' is booted..."
DEVICE_UDID=$(xcrun simctl list devices available -j \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['name'] == '${SIMULATOR_NAME}' and '${SIMULATOR_OS}'.replace('.', '-') in runtime.replace('.', '-'):
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null) || true

if [[ -n "$DEVICE_UDID" ]]; then
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
    echo "Simulator booted: $DEVICE_UDID"
else
    echo "Warning: Could not find simulator '$SIMULATOR_NAME' (OS $SIMULATOR_OS). xcodebuild will attempt to boot one."
fi

echo "Running UI tests with scheme '$SCHEME' for destination '$DESTINATION'..."
set +e
xcodebuild test -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -only-testing DUNEUITests \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    >"$LOG_FILE" 2>&1
TEST_EXIT=$?
set -e

if [[ "$TEST_EXIT" -ne 0 ]]; then
    echo ""
    echo "UI tests failed. Summary:"
    grep -n -E "TEST (SUCCEEDED|FAILED)|error:|failed|Executed" "$LOG_FILE" | tail -n 120 || true
    echo ""
    echo "Full log: $LOG_FILE"
    exit "$TEST_EXIT"
fi

echo "UI tests passed."
grep -n -E "TEST (SUCCEEDED|FAILED)|Executed" "$LOG_FILE" | tail -n 20 || true
