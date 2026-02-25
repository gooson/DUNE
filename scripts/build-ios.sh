#!/bin/bash
# Standard iOS build check for DUNE.
# - Regenerates project from xcodegen (unless --no-regen)
# - Builds with iOS Simulator destination (avoids generic platform ambiguity)
# - Prints concise failure summary

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNE"
DESTINATION="${DAILVE_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.2}"
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

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required. Install with: brew install xcodegen"
    exit 1
fi

if [[ "$REGENERATE" -eq 1 || ! -d "$PROJECT_FILE" ]]; then
    echo "Generating Xcode project from $PROJECT_SPEC..."
    xcodegen generate --spec "$PROJECT_SPEC" >/tmp/dune-xcodegen.log 2>&1

    # Post-process: xcodegen doesn't support Xcode 16.3 format (objectVersion 90)
    PBXPROJ="$PROJECT_FILE/project.pbxproj"
    sed -i '' 's/objectVersion = 77;/objectVersion = 90;/' "$PBXPROJ"
    sed -i '' 's/compatibilityVersion = "Xcode 14.0";/compatibilityVersion = "Xcode 16.3";/' "$PBXPROJ"
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
    rg -n "BUILD (SUCCEEDED|FAILED)|error:" "$LOG_FILE" | tail -n 120 || true
    echo ""
    echo "Full log: $LOG_FILE"
    exit "$BUILD_EXIT"
fi

echo "Build succeeded."
rg -n "BUILD (SUCCEEDED|FAILED)" "$LOG_FILE" | tail -n 20 || true
