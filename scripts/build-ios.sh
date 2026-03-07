#!/bin/bash
# Standard iOS build check for DUNE.
# - Regenerates project from xcodegen (unless --no-regen)
# - Builds generic iOS by default to avoid runtime-specific simulator failures
# - Prints concise failure summary

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNE"
DESTINATION="${DAILVE_IOS_DESTINATION:-generic/platform=iOS}"
DERIVED_DATA_DIR="${DAILVE_BUILD_DERIVED_DATA_DIR:-.deriveddata/build-ios}"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/ios-build.log"
XCODEBUILD_JOBS="${DAILVE_XCODEBUILD_JOBS-4}"
INDEX_STORE_ENABLED="${DAILVE_COMPILER_INDEX_STORE_ENABLE-NO}"
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
if [[ -n "$XCODEBUILD_JOBS" ]]; then
    echo "Using xcodebuild job cap: $XCODEBUILD_JOBS"
fi
set +e
build_cmd=(
    xcodebuild
    -project "$PROJECT_FILE"
    -scheme "$SCHEME"
    -destination "$DESTINATION"
    -derivedDataPath "$DERIVED_DATA_DIR"
)
if [[ -n "$XCODEBUILD_JOBS" ]]; then
    build_cmd+=(-jobs "$XCODEBUILD_JOBS")
fi
build_cmd+=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    COMPILER_INDEX_STORE_ENABLE="$INDEX_STORE_ENABLED"
    build
)
"${build_cmd[@]}" >"$LOG_FILE" 2>&1
BUILD_EXIT=$?
set -e

if [[ "$BUILD_EXIT" -ne 0 ]]; then
    echo ""
    echo "Build failed. Summary:"
    grep -a -n -E "BUILD (SUCCEEDED|FAILED)|error:" "$LOG_FILE" | tail -n 120 || true
    echo ""
    echo "Full log: $LOG_FILE"
    exit "$BUILD_EXIT"
fi

echo "Build succeeded."
grep -a -n -E "BUILD (SUCCEEDED|FAILED)" "$LOG_FILE" | tail -n 20 || true
