#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
BASE="${PROJECT_ROOT}/.claude/memory"
mkdir -p "$BASE"

DATE="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

cat >> "${BASE}/decisions.md" <<EOF

### ${DATE}
- Snapshot automático del flujo Claude Gentleman Native.
- Registrar aquí decisiones, convenciones nuevas, riesgos y follow-ups.
EOF
