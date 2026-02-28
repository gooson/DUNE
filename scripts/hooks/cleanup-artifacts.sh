#!/bin/bash
# Remove local build artifacts that should never remain in workspace state.

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

CANDIDATES=(
  ".xcodebuild"
  ".deriveddata"
  "DerivedData"
  "DUNE/.xcodebuild"
  "DUNE/.deriveddata"
)

removed=0

for rel in "${CANDIDATES[@]}"; do
  target="${ROOT_DIR}/${rel}"
  if [ -e "$target" ]; then
    rm -rf "$target" 2>/dev/null || true
    echo "Removed artifact: $rel"
    removed=1
  fi
done

if [ "$removed" -eq 0 ]; then
  echo "No build artifacts to clean."
fi
