#!/bin/bash
# Remove local build artifacts that should never remain in workspace state.

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

KEEP_DERIVEDDATA=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-deriveddata)
      KEEP_DERIVEDDATA=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--keep-deriveddata]"
      exit 2
      ;;
  esac
done

CANDIDATES=(
  ".xcodebuild"
  "DerivedData"
  "DUNE/.xcodebuild"
)

if [ "$KEEP_DERIVEDDATA" -eq 0 ]; then
  CANDIDATES+=(
    ".deriveddata"
    "DUNE/.deriveddata"
  )
fi

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
