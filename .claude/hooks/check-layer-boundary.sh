#!/bin/bash
# PostToolUse hook: Check Swift layer boundary violations after Edit/Write
# Domain layer must not import SwiftUI, UIKit, or SwiftData
# ViewModel must not import SwiftData or use ModelContext

set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only check Swift files modified by Edit or Write
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
  exit 0
fi

if [[ -z "$file_path" || ! "$file_path" == *.swift ]]; then
  exit 0
fi

# Skip test files
if [[ "$file_path" == *Tests* || "$file_path" == *Test.swift ]]; then
  exit 0
fi

warnings=""

# Check Domain layer files (must not import SwiftUI/UIKit/SwiftData)
if echo "$file_path" | grep -qE '/Domain/'; then
  if grep -qE '^\s*import\s+(SwiftUI|UIKit|SwiftData)' "$file_path" 2>/dev/null; then
    violations=$(grep -nE '^\s*import\s+(SwiftUI|UIKit|SwiftData)' "$file_path" 2>/dev/null || true)
    warnings="${warnings}⚠️ Layer Boundary Violation: Domain file imports UI/Data framework\n  File: ${file_path}\n  ${violations}\n  Rule: Domain layer may only import Foundation and HealthKit\n\n"
  fi
fi

# Check ViewModel files (must not import SwiftData or use ModelContext)
if echo "$file_path" | grep -qiE 'ViewModel\.swift$|VM\.swift$'; then
  if grep -qE '^\s*import\s+SwiftData' "$file_path" 2>/dev/null; then
    warnings="${warnings}⚠️ Layer Boundary Violation: ViewModel imports SwiftData\n  File: ${file_path}\n  Rule: ViewModel must not import SwiftData. Use createValidatedRecord() pattern.\n\n"
  fi
  if grep -qE 'ModelContext' "$file_path" 2>/dev/null; then
    warnings="${warnings}⚠️ Layer Boundary Violation: ViewModel references ModelContext\n  File: ${file_path}\n  Rule: ModelContext belongs in View layer, not ViewModel.\n\n"
  fi
fi

if [[ -n "$warnings" ]]; then
  echo -e "$warnings" >&2
fi

exit 0
