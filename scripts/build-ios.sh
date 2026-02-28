#!/bin/bash
# Standard iOS build check for DUNE.
# - Regenerates project from xcodegen (unless --no-regen)
# - Builds with iOS Simulator destination (avoids generic platform ambiguity)
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
DESTINATION="platform=iOS Simulator,name=${SIM_NAME},OS=${SIM_OS}"
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
