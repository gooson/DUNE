#!/bin/bash
# Run the opt-in model-backed AI evaluations on a worktree-owned simulator.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

LOG_FILE="${DAILVE_AI_EVALUATION_LOG_FILE:-.xcodebuild/ai-evaluations.log}"
RESULT_BUNDLE="$(dirname "$LOG_FILE")/ai-evaluations-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
REGENERATE=1
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-regen)
            REGENERATE=0
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-regen] [--dry-run]"
            exit 2
            ;;
    esac
done

# The dedicated generated scheme injects DUNE_RUN_LIVE_AI_EVALUATIONS=1 into
# DUNETests. Ordinary unit schemes leave the two model-backed tests disabled.
TEST_ARGS=(
    --ios-only
    --ios-scheme DUNEAIEvaluations
    --result-bundle-path "$RESULT_BUNDLE"
    --log-file "$LOG_FILE"
    --only-testing DUNETests/AIFeatureEvaluationTests
)
if [[ "$REGENERATE" -eq 0 ]]; then
    TEST_ARGS+=(--no-regen)
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'DRY_RUN_COMMAND='
    printf '%q ' "$ROOT_DIR/scripts/test-unit.sh" "${TEST_ARGS[@]}"
    printf '\n'
    exit 0
fi

if [[ -n "${DUNE_SIM_TEST_LOCK_FD:-}" ]]; then
    python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" --verify
else
    exec python3 "$ROOT_DIR/scripts/lib/simulator-test-lock.py" "$ROOT_DIR" -- "$ROOT_DIR/scripts/evaluate-ai-features.sh" "$@"
fi

mkdir -p "$(dirname "$LOG_FILE")"
# Preserve the existing evaluation-specific cache override while sharing the
# standard unit cache by default.
export DAILVE_UNIT_TEST_DERIVED_DATA_DIR="${DAILVE_AI_EVALUATION_DERIVED_DATA_DIR:-${DAILVE_UNIT_TEST_DERIVED_DATA_DIR:-.deriveddata/unit-tests}}"

set +e
python3 "$ROOT_DIR/scripts/lib/command-deadline.py" --seconds 1200 -- \
    "$ROOT_DIR/scripts/test-unit.sh" "${TEST_ARGS[@]}"
TEST_EXIT=$?
set -e

if [[ "$TEST_EXIT" -ne 0 ]]; then
    echo "AI feature evaluation failed. Summary:"
    grep -a -n -E "TEST (SUCCEEDED|FAILED)|error:|failed metric:|generation failed:" "$LOG_FILE" | tail -n 100 || true
    echo "Full log: $LOG_FILE"
    exit "$TEST_EXIT"
fi

RESULT_JSON="${LOG_FILE}.result.json"
if ! xcrun xcresulttool get test-results tests --path "$RESULT_BUNDLE" --compact >"$RESULT_JSON"; then
    echo "AI feature evaluation result could not be inspected. Bundle: $RESULT_BUNDLE" >&2
    exit 2
fi

if ! python3 "$ROOT_DIR/scripts/lib/verify-ai-evaluation-result.py" "$RESULT_JSON"; then
    echo "AI feature evaluation is incomplete. Bundle: $RESULT_BUNDLE" >&2
    exit 2
fi

echo "AI live feature evaluation passed. Full log: $LOG_FILE; bundle: $RESULT_BUNDLE"
