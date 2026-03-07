#!/bin/bash
# Shared xcodegen project regeneration logic.
# Sourced by build and test scripts — not executed directly.
#
# Required variables (set by caller):
#   PROJECT_SPEC  — path to project.yml
#   PROJECT_FILE  — path to .xcodeproj
#   REGENERATE    — 1 to regenerate, 0 to skip

ensure_tooling_path() {
    local candidates=(
        "/opt/homebrew/bin"
        "/usr/local/bin"
        "$HOME/.homebrew/bin"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" && ":$PATH:" != *":$candidate:"* ]]; then
            PATH="$candidate:$PATH"
        fi
    done
    export PATH
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
    exec "$ROOT_DIR/scripts/build-ios.sh" "$@"
fi

# Normalize a single xcscheme file to match Xcode 26 format.
# Prevents perpetual diffs caused by xcodegen generating v1.3 without
# runPostActionsOnFailure / onlyGenerateCoverageForSpecifiedTargets.
# Safe to call repeatedly (idempotent).
normalize_xcscheme() {
    local scheme_file="$1"
    [ -f "$scheme_file" ] || return 0

    sed -i '' 's/version = "1.3"/version = "1.7"/' "$scheme_file"
    if ! grep -q 'runPostActionsOnFailure' "$scheme_file"; then
        sed -i '' 's/buildImplicitDependencies = "YES">/buildImplicitDependencies = "YES"\
      runPostActionsOnFailure = "NO">/' "$scheme_file"
    fi
    if ! grep -q 'onlyGenerateCoverageForSpecifiedTargets' "$scheme_file"; then
        sed -i '' 's/shouldUseLaunchSchemeArgsEnv = "YES">/shouldUseLaunchSchemeArgsEnv = "YES"\
      onlyGenerateCoverageForSpecifiedTargets = "NO">/' "$scheme_file"
    fi
    if ! grep -q 'parallelizable' "$scheme_file"; then
        sed -i '' 's/skipped = "NO">/skipped = "NO"\
            parallelizable = "NO">/' "$scheme_file"
    fi
    if ! grep -q 'CommandLineArguments' "$scheme_file" && grep -q 'TestableReference' "$scheme_file"; then
        sed -i '' 's|      </Testables>|      </Testables>\
      <CommandLineArguments>\
      </CommandLineArguments>|' "$scheme_file"
    fi
}

# Normalize all xcscheme files under a given .xcodeproj directory.
normalize_all_xcschemes() {
    local project_dir="$1"
    for scheme_file in "$project_dir"/xcshareddata/xcschemes/*.xcscheme; do
        normalize_xcscheme "$scheme_file"
    done
}

regen_project() {
    ensure_tooling_path

    if ! command -v xcodegen >/dev/null 2>&1; then
        echo "error: xcodegen is required. Install with: brew install xcodegen"
        exit 1
    fi

    if [[ "$REGENERATE" -eq 1 || ! -d "$PROJECT_FILE" ]]; then
        echo "Generating Xcode project from $PROJECT_SPEC..."
        xcodegen generate --spec "$PROJECT_SPEC" >/tmp/dune-xcodegen.log 2>&1

        # Post-process: xcodegen doesn't support Xcode 16.3 format (objectVersion 90)
        local pbxproj="$PROJECT_FILE/project.pbxproj"
        sed -i '' 's/objectVersion = 77;/objectVersion = 90;/' "$pbxproj"
        sed -i '' 's/compatibilityVersion = "Xcode 14.0";/compatibilityVersion = "Xcode 16.3";/' "$pbxproj"

        # Post-process xcschemes to match Xcode 26 format
        normalize_all_xcschemes "$PROJECT_FILE"
    fi
}
