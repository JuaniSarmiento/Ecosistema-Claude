#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Run this manually for interactive verification:"
echo "  claude --plugin-dir \"$ROOT\""
echo
echo "Then verify inside Claude:"
echo "  /help"
echo "  /agents"
echo "  /hooks"
echo "  /reload-plugins"
