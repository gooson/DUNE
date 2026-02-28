#!/bin/bash
# Shared xcodegen project regeneration logic.
# Sourced by build and test scripts — not executed directly.
#
# Required variables (set by caller):
#   PROJECT_SPEC  — path to project.yml
#   PROJECT_FILE  — path to .xcodeproj
#   REGENERATE    — 1 to regenerate, 0 to skip

regen_project() {
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

        # Post-process xcschemes: xcodegen generates version 1.3 without some attributes
        # that Xcode 26 adds on open, causing perpetual diffs.
        for scheme_file in "$PROJECT_FILE"/xcshareddata/xcschemes/*.xcscheme; do
            [ -f "$scheme_file" ] || continue
            sed -i '' 's/version = "1.3"/version = "1.7"/' "$scheme_file"
            if ! grep -q 'runPostActionsOnFailure' "$scheme_file"; then
                sed -i '' 's/buildImplicitDependencies = "YES">/buildImplicitDependencies = "YES"\
      runPostActionsOnFailure = "NO">/' "$scheme_file"
            fi
            if ! grep -q 'onlyGenerateCoverageForSpecifiedTargets' "$scheme_file"; then
                sed -i '' 's/shouldUseLaunchSchemeArgsEnv = "YES">/shouldUseLaunchSchemeArgsEnv = "YES"\
      onlyGenerateCoverageForSpecifiedTargets = "NO">/' "$scheme_file"
            fi
        done
    fi
}
