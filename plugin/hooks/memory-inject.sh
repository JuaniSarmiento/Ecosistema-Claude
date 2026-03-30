#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"
DB_PATH="${GENTLEMAN_MEMORY_DB:-$HOME/.claude/gentleman-memory/memory.db}"

# --- Primary source: SQLite (gentleman-memory) ---
if [ -f "$DB_PATH" ]; then
  python3 -c "
import sqlite3, os, json, sys

db_path = os.environ.get('GENTLEMAN_MEMORY_DB', os.path.expanduser('~/.claude/gentleman-memory/memory.db'))
if not os.path.exists(db_path):
    sys.exit(0)
conn = sqlite3.connect(db_path)
project = os.environ.get('PROJECT_NAME', os.path.basename(os.getcwd()))
rows = conn.execute('''
    SELECT title, content, type, updated_at FROM observations
    WHERE project = ? OR project IS NULL
    ORDER BY updated_at DESC LIMIT 20
''', (project,)).fetchall()
if rows:
    print('# Project Memory (from gentleman-memory)')
    print()
    for title, content, obs_type, updated in rows:
        print(f'## {title} [{obs_type}] ({updated})')
        # Truncate long content
        if len(content) > 1000:
            print(content[:1000] + '...(truncated)')
        else:
            print(content)
        print()
conn.close()
" 2>/dev/null && exit 0
fi

# --- Fallback: file-based memory ---
BASE="${PROJECT_ROOT}/.claude/memory"

for f in conventions.md current-work.md decisions.md open-questions.md; do
  if [ -f "${BASE}/${f}" ]; then
    echo
    echo "## MEMORY:${f}"
    sed -n '1,200p' "${BASE}/${f}"
  fi
done
