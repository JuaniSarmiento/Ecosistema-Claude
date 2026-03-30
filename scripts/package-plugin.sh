#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${ROOT}/dist"
NAME="claude-gentleman-native"

mkdir -p "$DIST"
rm -f "${DIST}/${NAME}.tar.gz"

tar -czf "${DIST}/${NAME}.tar.gz"   -C "$ROOT"   .claude-plugin   settings.json   .mcp.json   Makefile   README.md   agents   skills   hooks   servers   templates   scripts   tests

echo "Created: ${DIST}/${NAME}.tar.gz"
