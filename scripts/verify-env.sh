#!/usr/bin/env bash
set -euo pipefail

echo "Checking Claude Code..."
command -v claude >/dev/null 2>&1 || { echo "claude not found"; exit 1; }

echo "Checking Python..."
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }

echo "Checking jq..."
command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }

echo "Claude version:"
claude --version

echo "Potential conflicting installations:"
which -a claude || true
