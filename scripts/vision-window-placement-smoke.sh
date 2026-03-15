#!/bin/bash
# Run a reproducible visionOS window placement smoke flow.
# - Regenerates the Xcode project unless --no-regen is passed
# - Builds DUNEVision for visionOS Simulator
# - Boots an available Apple Vision Pro simulator
# - Installs and launches the app with placement-smoke launch arguments
# - Captures a screenshot artifact for manual verification

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/regen-project.sh"

PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
SCHEME="DUNEVision"
BUNDLE_ID="${DAILVE_VISION_BUNDLE_ID:-com.raftel.dailve.vision}"
BUILD_DESTINATION="${DAILVE_VISION_BUILD_DESTINATION:-generic/platform=visionOS Simulator}"
SIMULATOR_NAME="${DAILVE_VISION_SIMULATOR:-Apple Vision Pro}"
SIMULATOR_OS="${DAILVE_VISION_OS:-}"
DERIVED_DATA_DIR="${DAILVE_VISION_SMOKE_DERIVED_DATA_DIR:-.deriveddata/vision-window-placement-smoke}"
ARTIFACT_DIR="${DAILVE_VISION_SMOKE_ARTIFACT_DIR:-.tmp/vision-window-placement-smoke}"
LOG_DIR=".xcodebuild"
LOG_FILE="$LOG_DIR/vision-window-placement-smoke.log"
OUTPUT_PATH=""
WAIT_SECONDS="${DAILVE_VISION_SMOKE_WAIT_SECONDS:-8}"
REGENERATE=1
SKIP_BUILD=0

usage() {
    cat <<'EOF'
Usage: scripts/vision-window-placement-smoke.sh [options]

Options:
  --no-regen            Skip xcodegen regeneration unless the project is missing
  --skip-build          Reuse the existing derived data app bundle
  --output <path>       Screenshot output path
  --wait-seconds <n>    Delay before screenshot capture (default: 8)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-regen)
            REGENERATE=0
            shift
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        --wait-seconds)
            WAIT_SECONDS="$2"
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

mkdir -p "$DERIVED_DATA_DIR" "$ARTIFACT_DIR" "$LOG_DIR"
regen_project

if [[ -z "$OUTPUT_PATH" ]]; then
    OUTPUT_PATH="$ARTIFACT_DIR/window-placement-$(date +%Y%m%d-%H%M%S).png"
fi

if [[ "$SKIP_BUILD" -ne 1 ]]; then
    echo "Building scheme '$SCHEME' for destination '$BUILD_DESTINATION'..."
    set +e
    xcodebuild build \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -destination "$BUILD_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        >"$LOG_FILE" 2>&1
    BUILD_EXIT=$?
    set -e

    if [[ "$BUILD_EXIT" -ne 0 ]]; then
        echo ""
        echo "Vision smoke build failed. Summary:"
        grep -a -n -E "BUILD (SUCCEEDED|FAILED)|error:" "$LOG_FILE" | tail -n 120 || true
        echo ""
        echo "Full log: $LOG_FILE"
        exit "$BUILD_EXIT"
    fi
fi

APP_PATH="$(find "$DERIVED_DATA_DIR/Build/Products" -path '*DUNEVision.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
    echo "Could not find DUNEVision.app under $DERIVED_DATA_DIR/Build/Products"
    exit 1
fi

echo "Resolving an available visionOS simulator..."
DEVICE_INFO="$(
    SIMULATOR_NAME="$SIMULATOR_NAME" SIMULATOR_OS="$SIMULATOR_OS" \
    xcrun simctl list devices available -j | python3 -c '
import json
import os
import re
import sys

requested_name = os.environ.get("SIMULATOR_NAME", "")
requested_os = os.environ.get("SIMULATOR_OS", "")
data = json.load(sys.stdin)
candidates = []

def parse_os(runtime: str) -> str:
    match = re.search(r"(?:xros|visionos)-(\\d+)-(\\d+)", runtime, re.IGNORECASE)
    return f"{match.group(1)}.{match.group(2)}" if match else ""

for runtime, devices in data["devices"].items():
    runtime_lower = runtime.lower()
    if "visionos" not in runtime_lower and "xros" not in runtime_lower:
        continue
    os_version = parse_os(runtime)
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        candidates.append((device["name"], os_version, device["udid"]))

def emit(choice):
    name, os_version, udid = choice
    print("\t".join([udid, name, os_version]))
    sys.exit(0)

if requested_os:
    for candidate in candidates:
        if candidate[0] == requested_name and candidate[1] == requested_os:
            emit(candidate)

for candidate in candidates:
    if candidate[0] == requested_name:
        emit(candidate)

for candidate in candidates:
    if candidate[0].startswith("Apple Vision"):
        emit(candidate)

if candidates:
    emit(candidates[0])

sys.exit(1)
'
)" || true

if [[ -z "$DEVICE_INFO" ]]; then
    echo "No available visionOS simulator found."
    exit 1
fi

IFS=$'\t' read -r DEVICE_UDID RESOLVED_SIMULATOR_NAME RESOLVED_SIMULATOR_OS <<< "$DEVICE_INFO"
echo "Using simulator: $RESOLVED_SIMULATOR_NAME (${RESOLVED_SIMULATOR_OS:-unknown}) [$DEVICE_UDID]"

xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_UDID" -b
xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

echo "Launching placement smoke flow..."
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" \
    --seed-mock \
    --vision-window-placement-smoke

echo "Waiting ${WAIT_SECONDS}s for windows to open..."
sleep "$WAIT_SECONDS"

echo "Capturing screenshot to $OUTPUT_PATH"
xcrun simctl io "$DEVICE_UDID" screenshot "$OUTPUT_PATH"

NOTE_PATH="${OUTPUT_PATH%.png}.txt"
cat >"$NOTE_PATH" <<EOF
Vision window placement smoke
date: $(date '+%Y-%m-%d %H:%M:%S')
simulator: $RESOLVED_SIMULATOR_NAME (${RESOLVED_SIMULATOR_OS:-unknown})
udid: $DEVICE_UDID
app: $APP_PATH
launch_args: --seed-mock --vision-window-placement-smoke
screenshot: $OUTPUT_PATH
EOF

echo "Smoke artifact saved:"
echo "  Screenshot: $OUTPUT_PATH"
echo "  Note: $NOTE_PATH"
