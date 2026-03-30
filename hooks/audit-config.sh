#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${HOME}/claude-gentleman-config-audit.log"
INPUT="$(cat)"
echo "$INPUT" | jq -c '{timestamp: now | todate, source, file_path, hook_event_name}' >> "$LOG_FILE"
