#!/bin/bash
# Pre-commit hook: validate before committing
# Install: ln -sf ../../scripts/hooks/pre-commit.sh .git/hooks/pre-commit

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STAGED_FILES="$(git diff --cached --name-only)"

has_staged_match() {
    local pattern="$1"
    [[ -n "$STAGED_FILES" ]] && printf '%s\n' "$STAGED_FILES" | grep -Eq "$pattern"
}

append_unique_target() {
    local target="$1"
    local existing

    for existing in "${TARGETED_BUILDS[@]-}"; do
        [[ -z "$existing" ]] && continue
        if [[ "$existing" == "$target" ]]; then
            return
        fi
    done

    TARGETED_BUILDS+=("$target")
}

echo "Running pre-commit checks..."

# Ensure xcscheme clean filter is configured (idempotent, fast).
if [[ "$(git config --get filter.xcscheme.clean 2>/dev/null)" != "scripts/lib/xcscheme-clean-filter.sh" ]]; then
    git config filter.xcscheme.clean 'scripts/lib/xcscheme-clean-filter.sh'
    git config filter.xcscheme.smudge cat
fi

# Always clean local build artifacts before validating commit state.
cleanup_args=()
if [ "${DAILVE_PRECOMMIT_CLEAN_DERIVEDDATA:-0}" != "1" ]; then
    cleanup_args+=(--keep-deriveddata)
fi
"$ROOT_DIR/scripts/hooks/cleanup-artifacts.sh" "${cleanup_args[@]}"
# Check for secrets/credentials in staged files
if git diff --cached --diff-filter=ACM -U0 | grep -iE "(api_key|api_secret|secret_key|password|token|credential|private_key)\s*[:=]" | grep -v "test" | grep -v ".md" | grep -v "#"; then
    echo ""
    echo "WARNING: Possible secrets detected in staged files."
    echo "Please review and remove sensitive data before committing."
    echo "If this is intentional (test data, etc.), use --no-verify to bypass."
    exit 1
fi

# Check for .env files being committed
if has_staged_match "^\\.env"; then
    echo ""
    echo "ERROR: .env file should not be committed."
    echo "Add it to .gitignore instead."
    exit 1
fi

# Validate TODO file naming convention
if has_staged_match "^todos/.*\\.md$"; then
    PATTERN="^[0-9]{3}-(pending|ready|in-progress|done)-(p1|p2|p3)-[a-z0-9-]+\.md$"
    ERRORS=0
    while IFS= read -r file; do
        [[ "$file" == *".gitkeep" ]] && continue
        basename_file=$(basename "$file")
        if ! echo "$basename_file" | grep -qE "$PATTERN"; then
            echo "ERROR: Invalid TODO filename: $basename_file"
            echo "  Expected: NNN-STATUS-PRIORITY-description.md"
            echo "  Example:  001-ready-p1-fix-auth-bypass.md"
            ERRORS=$((ERRORS + 1))
        fi
    done < <(printf '%s\n' "$STAGED_FILES" | grep -E "^todos/.*\.md$" || true)
    if [ $ERRORS -gt 0 ]; then
        exit 1
    fi
fi

# Run project-specific checks (uncomment as needed)
# npm test 2>/dev/null || true
# npm run lint 2>/dev/null || true
# npm run typecheck 2>/dev/null || true
# pytest 2>/dev/null || true

# Build checks for staged source/project changes (can be skipped with DAILVE_SKIP_PRECOMMIT_BUILD=1)
if has_staged_match "^(DUNE/.*\\.(swift|plist|entitlements)|DUNE/project\\.yml|DUNEWatch/.*\\.(swift|plist|entitlements)|DUNEWidget/.*\\.(swift|plist|entitlements)|Shared/.*\\.swift|DUNETests/.*\\.(swift|plist)|DUNEWatchTests/.*\\.(swift|plist)|DUNEUITests/.*\\.(swift|plist)|DUNEWatchUITests/.*\\.(swift|plist))$"; then
    if [ "${DAILVE_SKIP_PRECOMMIT_BUILD:-0}" = "1" ]; then
        echo "Skipping pre-commit build checks (DAILVE_SKIP_PRECOMMIT_BUILD=1)."
    else
        FULL_BUILD_REQUIRED=0
        REGEN_REQUIRED=0
        TARGETED_BUILDS=()

        if has_staged_match "^DUNE/project\\.yml$"; then
            FULL_BUILD_REQUIRED=1
            REGEN_REQUIRED=1
        fi

        if has_staged_match "^(DUNE/.*\\.(swift|plist|entitlements)|DUNEWatch/.*\\.(swift|plist|entitlements)|DUNEWidget/.*\\.(swift|plist|entitlements)|Shared/.*\\.swift)$"; then
            FULL_BUILD_REQUIRED=1
        fi

        if [ "$FULL_BUILD_REQUIRED" -eq 1 ]; then
            echo "Running full app build check..."
            if [ "$REGEN_REQUIRED" -eq 1 ]; then
                DAILVE_FAST_LOCAL_BUILD=1 "$ROOT_DIR/scripts/build-ios.sh"
            else
                DAILVE_FAST_LOCAL_BUILD=1 "$ROOT_DIR/scripts/build-ios.sh" --no-regen
            fi
        else
            if has_staged_match "^DUNETests/.*\\.(swift|plist)$"; then
                append_unique_target "DUNETests ios"
            fi
            if has_staged_match "^DUNEWatchTests/.*\\.(swift|plist)$"; then
                append_unique_target "DUNEWatchTests watchos"
            fi
            if has_staged_match "^DUNEUITests/.*\\.(swift|plist)$"; then
                append_unique_target "DUNEUITests ios"
            fi
            if has_staged_match "^DUNEWatchUITests/.*\\.(swift|plist)$"; then
                append_unique_target "DUNEWatchUITests watchos"
            fi

            for target in "${TARGETED_BUILDS[@]-}"; do
                [[ -z "$target" ]] && continue
                read -r scheme platform <<<"$target"
                echo "Running targeted compile check for $scheme..."
                DAILVE_FAST_LOCAL_BUILD=1 "$ROOT_DIR/scripts/build-target.sh" \
                    --scheme "$scheme" \
                    --platform "$platform" \
                    --build-for-testing \
                    --no-regen \
                    --log-file "$ROOT_DIR/.xcodebuild/pre-commit-${scheme}.log"
            done
        fi
    fi
fi

echo "Pre-commit checks passed."
