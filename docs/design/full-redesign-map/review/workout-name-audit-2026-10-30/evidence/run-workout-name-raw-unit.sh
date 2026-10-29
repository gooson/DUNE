#!/bin/bash
set -euo pipefail
cd /Users/shanks/.codex/worktrees/96f8/Health
REGENERATE=1
PROJECT_SPEC=DUNE/project.yml
PROJECT_FILE=DUNE/DUNE.xcodeproj
source scripts/lib/regen-project.sh
regen_project
exec python3 scripts/lib/simulator-test-lock.py "$PWD" -- python3 scripts/lib/command-deadline.py --seconds 300 -- xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination id=9905027B-0A4A-4A45-84D0-98431BE94BAC -derivedDataPath .deriveddata/cardio-place-search -parallel-testing-enabled NO -only-testing DUNETests/WorkoutTypeCorrectionStoreTests/testManualLegacyRawValuesKeepActivityClassification CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
