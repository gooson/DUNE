#!/bin/bash
# Standard iOS build check for DUNE.
# - Regenerates project from xcodegen (unless --no-regen)
# - Builds generic iOS by default to avoid runtime-specific simulator failures
# - Prints concise failure summary

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"
source "$ROOT_DIR/scripts/lib/xcodebuild-resources.sh"
configure_xcodebuild_resources build

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNE"
DESTINATION="${DAILVE_IOS_DESTINATION:-generic/platform=iOS}"
DERIVED_DATA_DIR="${DAILVE_BUILD_DERIVED_DATA_DIR:-.deriveddata/build-ios}"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/ios-build.log"
REGENERATE=1
XCODEBUILD_SETTINGS=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
)

if [[ "${DAILVE_FAST_LOCAL_BUILD:-0}" == "1" ]]; then
    XCODEBUILD_SETTINGS+=(
        ONLY_ACTIVE_ARCH=YES
        COMPILER_INDEX_STORE_ENABLE=NO
    )
fi

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

echo "Checking string catalog format and manual extraction state..."
swift scripts/format-xcstrings.swift --check --check-manual

echo "Building scheme '$SCHEME' for destination '$DESTINATION'..."
set +e
build_cmd=(
    xcodebuild
    -project "$PROJECT_FILE"
    -scheme "$SCHEME"
    -destination "$DESTINATION"
    -derivedDataPath "$DERIVED_DATA_DIR"
    ${XCODEBUILD_RESOURCE_ARGS[@]+"${XCODEBUILD_RESOURCE_ARGS[@]}"}
)
build_cmd+=(
    "${XCODEBUILD_SETTINGS[@]}"
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

# Xcode may discover missing Swift or Info.plist keys while building.
# Preserve that evidence and fail validation until the entries are reviewed.
if ! swift scripts/format-xcstrings.swift --check --check-manual; then
    echo "String catalogs changed during the build. Register new keys as manual, review translations, format, and rebuild."
    exit 1
fi
