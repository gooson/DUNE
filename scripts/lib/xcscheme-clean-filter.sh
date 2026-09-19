#!/bin/bash
# Git clean filter for .xcscheme files.
# Normalizes scheme version and attributes to match Xcode 26 format,
# preventing perpetual diffs from xcodegen (v1.3) vs Xcode (v1.7).
#
# Setup (run once per clone):
#   git config filter.xcscheme.clean 'scripts/lib/xcscheme-clean-filter.sh'
#   git config filter.xcscheme.smudge cat
#
# .gitattributes entry (already configured):
#   *.xcscheme filter=xcscheme

set -euo pipefail

# Read stdin into temp file for sed processing
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp"

# Use the same normalization as project generation and all build/test scripts.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/regen-project.sh"
normalize_xcscheme "$tmp"

cat "$tmp"
