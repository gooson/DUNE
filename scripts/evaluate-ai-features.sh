#!/bin/bash
# Run only the AI feature evaluation suite on an Apple Intelligence capable device/simulator.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "${DUNE_SIM_TEST_LOCK_FD:-}" ]]; then
    python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" --verify
else
    exec python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" -- "$ROOT_DIR/scripts/evaluate-ai-features.sh" "$@"
fi

source "$ROOT_DIR/scripts/lib/regen-project.sh"
PROJECT_SPEC="DUNE/project.yml"
PROJECT_FILE="DUNE/DUNE.xcodeproj"
DESTINATION="${DAILVE_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
DERIVED_DATA_DIR="${DAILVE_AI_EVALUATION_DERIVED_DATA_DIR:-.deriveddata/ai-evaluations}"
LOG_FILE="${DAILVE_AI_EVALUATION_LOG_FILE:-.xcodebuild/ai-evaluations.log}"
REGENERATE=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-regen)
            REGENERATE=0
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen]"
            exit 2
            ;;
    esac
done

mkdir -p "$(dirname "$LOG_FILE")" "$DERIVED_DATA_DIR"
regen_project

set +e
xcodebuild test \
    -project "$PROJECT_FILE" \
    -scheme DUNETests \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -only-testing:DUNETests/AIFeatureEvaluationTests \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    -quiet >"$LOG_FILE" 2>&1
TEST_EXIT=$?
set -e

if [[ "$TEST_EXIT" -ne 0 ]]; then
    echo "AI feature evaluation failed. Summary:"
    grep -a -n -E "TEST (SUCCEEDED|FAILED)|error:|failed metric:|generation failed:" "$LOG_FILE" | tail -n 100 || true
    echo "Full log: $LOG_FILE"
    exit "$TEST_EXIT"
fi

echo "AI feature evaluation passed. Full log: $LOG_FILE"
