#!/bin/bash
# Targeted compile check for a specific Xcode scheme.
# - Regenerates project from xcodegen only when requested or missing
# - Supports build-for-testing for test-target fast gates
# - Prints concise failure summary

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
DERIVED_DATA_DIR=".deriveddata"
LOG_DIR=".xcodebuild"
SCHEME=""
PLATFORM=""
ACTION="build-for-testing"
REGENERATE=1
LOG_FILE=""
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

usage() {
    cat <<'EOF'
Usage: scripts/build-target.sh --scheme <scheme> --platform <ios|watchos|visionos> [options]

Options:
  --build                 Use xcodebuild build
  --build-for-testing     Use xcodebuild build-for-testing (default)
  --no-regen             Skip xcodegen regeneration unless the project is missing
  --log-file <path>      Write full xcodebuild log to the given path
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --build)
            ACTION="build"
            shift
            ;;
        --build-for-testing)
            ACTION="build-for-testing"
            shift
            ;;
        --no-regen)
            REGENERATE=0
            shift
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

if [[ -z "$SCHEME" || -z "$PLATFORM" ]]; then
    usage
    exit 2
fi

resolve_destination() {
    case "$PLATFORM:$ACTION" in
        ios:build)
            echo "${DAILVE_IOS_DESTINATION:-generic/platform=iOS}"
            ;;
        ios:build-for-testing)
            echo "${DAILVE_IOS_DESTINATION:-generic/platform=iOS Simulator}"
            ;;
        watchos:build)
            echo "${DAILVE_WATCH_DESTINATION:-generic/platform=watchOS}"
            ;;
        watchos:build-for-testing)
            echo "${DAILVE_WATCH_DESTINATION:-generic/platform=watchOS Simulator}"
            ;;
        visionos:build)
            echo "${DAILVE_VISION_DESTINATION:-generic/platform=visionOS}"
            ;;
        visionos:build-for-testing)
            echo "${DAILVE_VISION_DESTINATION:-generic/platform=visionOS Simulator}"
            ;;
        *)
            echo "Unsupported platform/action combination: ${PLATFORM}:${ACTION}"
            exit 2
            ;;
    esac
}

DESTINATION="$(resolve_destination)"

mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR"
if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$LOG_DIR/${SCHEME}-${ACTION}.log"
fi

regen_project

echo "Running $ACTION for scheme '$SCHEME' on '$DESTINATION'..."
set +e
xcodebuild "$ACTION" \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    "${XCODEBUILD_SETTINGS[@]}" \
    >"$LOG_FILE" 2>&1
BUILD_EXIT=$?
set -e

if [[ "$BUILD_EXIT" -ne 0 ]]; then
    echo ""
    echo "Targeted build failed. Summary:"
    grep -n -E "(BUILD|TEST BUILD) (SUCCEEDED|FAILED)|error:" "$LOG_FILE" | tail -n 120 || true
    echo ""
    echo "Full log: $LOG_FILE"
    exit "$BUILD_EXIT"
fi

echo "Targeted build succeeded."
grep -n -E "(BUILD|TEST BUILD) (SUCCEEDED|FAILED)" "$LOG_FILE" | tail -n 20 || true
