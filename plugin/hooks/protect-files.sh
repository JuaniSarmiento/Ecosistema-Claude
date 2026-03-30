#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"

PROTECTED_PATTERNS=(
  ".env"
  ".secrets"
  ".pem"
  ".key"
  ".p12"
  ".git/"
  ".claude/settings.json"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    jq -nc --arg reason "Archivo protegido por política del plugin: $pattern" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
done

exit 0
