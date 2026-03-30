#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // "false"')" = "true" ]; then
  exit 0
fi

echo '{"ok": true}'
