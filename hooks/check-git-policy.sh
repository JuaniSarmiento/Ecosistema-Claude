#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"

DENY=(
  "git reset --hard"
  "git clean -fd"
  "git clean -fdx"
  "git push --force"
  "git push -f"
)

for banned in "${DENY[@]}"; do
  if [[ "$CMD" == *"$banned"* ]]; then
    jq -nc --arg reason "Operación git destructiva bloqueada: $banned" '{
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
