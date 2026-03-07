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

# version 1.3 → 1.7
sed -i '' 's/version = "1.3"/version = "1.7"/' "$tmp"

# Add runPostActionsOnFailure if missing (BuildAction closing tag)
if ! grep -q 'runPostActionsOnFailure' "$tmp"; then
    sed -i '' 's/buildImplicitDependencies = "YES">/buildImplicitDependencies = "YES"\
      runPostActionsOnFailure = "NO">/' "$tmp"
fi

# Add onlyGenerateCoverageForSpecifiedTargets if missing (TestAction closing tag)
if ! grep -q 'onlyGenerateCoverageForSpecifiedTargets' "$tmp"; then
    sed -i '' 's/shouldUseLaunchSchemeArgsEnv = "YES">/shouldUseLaunchSchemeArgsEnv = "YES"\
      onlyGenerateCoverageForSpecifiedTargets = "NO">/' "$tmp"
fi

# Add parallelizable = "NO" to TestableReference if missing
if ! grep -q 'parallelizable' "$tmp"; then
    sed -i '' 's/skipped = "NO">/skipped = "NO"\
            parallelizable = "NO">/' "$tmp"
fi

# Add empty CommandLineArguments after </Testables> if missing (only for schemes with test targets)
if ! grep -q 'CommandLineArguments' "$tmp" && grep -q 'TestableReference' "$tmp"; then
    sed -i '' 's|      </Testables>|      </Testables>\
      <CommandLineArguments>\
      </CommandLineArguments>|' "$tmp"
fi

cat "$tmp"
