#!/bin/bash
# Pre-commit hook: validate before committing
# Install: ln -sf ../../scripts/hooks/pre-commit.sh .git/hooks/pre-commit

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "Running pre-commit checks..."

# Check for secrets/credentials in staged files
if git diff --cached --diff-filter=ACM -U0 | grep -iE "(api_key|api_secret|secret_key|password|token|credential|private_key)\s*[:=]" | grep -v "test" | grep -v ".md" | grep -v "#"; then
    echo ""
    echo "WARNING: Possible secrets detected in staged files."
    echo "Please review and remove sensitive data before committing."
    echo "If this is intentional (test data, etc.), use --no-verify to bypass."
    exit 1
fi

# Check for .env files being committed
if git diff --cached --name-only | grep -E "^\.env"; then
    echo ""
    echo "ERROR: .env file should not be committed."
    echo "Add it to .gitignore instead."
    exit 1
fi

# Validate TODO file naming convention
if git diff --cached --name-only | grep -E "^todos/.*\.md$" | grep -v ".gitkeep"; then
    PATTERN="^[0-9]{3}-(pending|ready|in-progress|done)-(p1|p2|p3)-[a-z0-9-]+\.md$"
    ERRORS=0
    for file in $(git diff --cached --name-only | grep -E "^todos/.*\.md$" | grep -v ".gitkeep"); do
        basename_file=$(basename "$file")
        if ! echo "$basename_file" | grep -qE "$PATTERN"; then
            echo "ERROR: Invalid TODO filename: $basename_file"
            echo "  Expected: NNN-STATUS-PRIORITY-description.md"
            echo "  Example:  001-ready-p1-fix-auth-bypass.md"
            ERRORS=$((ERRORS + 1))
        fi
    done
    if [ $ERRORS -gt 0 ]; then
        exit 1
    fi
fi

# Run project-specific checks (uncomment as needed)
# npm test 2>/dev/null || true
# npm run lint 2>/dev/null || true
# npm run typecheck 2>/dev/null || true
# pytest 2>/dev/null || true

# iOS build check for Swift/Xcode changes (can be skipped with DAILVE_SKIP_PRECOMMIT_BUILD=1)
if git diff --cached --name-only | grep -Eq "^(Dailve/|DailveTests/|DailveUITests/|DailveWatch/).*\\.(swift|yml|plist|entitlements)$"; then
    if [ "${DAILVE_SKIP_PRECOMMIT_BUILD:-0}" = "1" ]; then
        echo "Skipping iOS build check (DAILVE_SKIP_PRECOMMIT_BUILD=1)."
    else
        echo "Running iOS build check..."
        "$ROOT_DIR/scripts/build-ios.sh"
    fi
fi

echo "Pre-commit checks passed."
