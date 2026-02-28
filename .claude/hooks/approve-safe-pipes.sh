#!/bin/bash
# PreToolUse hook: auto-approve safe piped/redirected commands
# Claude Code's Bash(cmd:*) patterns don't reliably match pipes and redirects.
# This hook approves commands where all segments are safe utilities.

set -euo pipefail

SAFE_COMMANDS=(
  cd git gh ls cat head tail grep sort diff mkdir cp mv rm touch chmod
  swift swiftc xcodebuild xcodegen xcode-select xcrun
  brew echo python3 pip3 npm npx node ruby
  wc xargs find sed awk uniq cut tr tee date
  realpath dirname basename plutil defaults stat file env export
  curl jq zip unzip tar ln killall ps lsof du uname
  pbcopy pbpaste pwd which open done bash
  scripts/build-ios.sh
)

# Read hook input from stdin
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
  exit 0
fi

# Strip redirects (2>/dev/null, 2>&1, >/dev/null, etc.) for cleaner parsing
cleaned=$(echo "$command" | sed -E 's/[0-9]*>[>&]*[^ ]*//g; s/[0-9]*<[^ ]*//g')

# Split by pipe, semicolon, && to get individual commands
# Then check each segment's first word against the safe list
while IFS= read -r segment; do
  # Trim whitespace
  segment=$(echo "$segment" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$segment" ]] && continue

  # Get first word (the command)
  first_word=$(echo "$segment" | awk '{print $1}')

  # Check against safe list
  found=false
  for safe in "${SAFE_COMMANDS[@]}"; do
    if [[ "$first_word" == "$safe" || "$first_word" == */"$safe" ]]; then
      found=true
      break
    fi
  done

  if [[ "$found" == false ]]; then
    # Unknown command found — let Claude Code's normal permission flow handle it
    exit 0
  fi
done < <(echo "$cleaned" | tr '|' '\n' | tr ';' '\n' | sed 's/&&/\n/g')

# All segments are safe — approve
echo '{"decision":"approve"}'
exit 0
