#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASSED=0
FAILED=0

pass() {
  echo "  PASS: $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo "  FAIL: $1"
  FAILED=$((FAILED + 1))
}

# ─── Original tests ──────────────────────────────────────────────

echo "=== protect-files.sh ==="

echo "Test 1: protect-files denies .env edits"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-edit-env.json" | "$ROOT/hooks/protect-files.sh")
if echo "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then
  pass "blocks .env edits"
else
  fail "blocks .env edits"
fi

echo "=== check-git-policy.sh ==="

echo "Test 2: check-git-policy denies git reset --hard"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-git-reset.json" | "$ROOT/hooks/check-git-policy.sh")
if echo "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then
  pass "blocks git reset --hard"
else
  fail "blocks git reset --hard"
fi

echo "=== memory-inject.sh (file-based, original) ==="

echo "Test 3: memory-inject prints conventions from files"
mkdir -p "$TMP/.claude/memory"
echo "We use pnpm in this repository." > "$TMP/.claude/memory/conventions.md"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TMP" GENTLEMAN_MEMORY_DB="/nonexistent/memory.db" "$ROOT/hooks/memory-inject.sh")
if echo "$OUTPUT" | grep -q "pnpm"; then
  pass "reads conventions from .claude/memory files"
else
  fail "reads conventions from .claude/memory files"
fi

# ─── New tests: protect-files.sh ──────────────────────────────────

echo ""
echo "=== protect-files.sh (additional) ==="

echo "Test 4: protect-files allows normal files"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-edit-normal.json" | "$ROOT/hooks/protect-files.sh")
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ] && ! echo "$OUTPUT" | grep -q "deny"; then
  pass "allows /tmp/demo/src/app.ts"
else
  fail "allows /tmp/demo/src/app.ts (exit=$EXIT_CODE, output=$OUTPUT)"
fi

echo "Test 5: protect-files blocks .pem files"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-edit-pem.json" | "$ROOT/hooks/protect-files.sh")
if echo "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then
  pass "blocks cert.pem"
else
  fail "blocks cert.pem"
fi

echo "Test 6: protect-files blocks .claude/settings.json"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-edit-claude-settings.json" | "$ROOT/hooks/protect-files.sh")
if echo "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then
  pass "blocks .claude/settings.json"
else
  fail "blocks .claude/settings.json"
fi

# ─── New tests: check-git-policy.sh ──────────────────────────────

echo ""
echo "=== check-git-policy.sh (additional) ==="

echo "Test 7: check-git-policy allows safe git commit"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-git-commit.json" | "$ROOT/hooks/check-git-policy.sh")
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ] && ! echo "$OUTPUT" | grep -q "deny"; then
  pass "allows git commit -m test"
else
  fail "allows git commit -m test (exit=$EXIT_CODE, output=$OUTPUT)"
fi

echo "Test 8: check-git-policy allows safe git push (no --force)"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-git-push-safe.json" | "$ROOT/hooks/check-git-policy.sh")
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ] && ! echo "$OUTPUT" | grep -q "deny"; then
  pass "allows git push origin main"
else
  fail "allows git push origin main (exit=$EXIT_CODE, output=$OUTPUT)"
fi

echo "Test 9: check-git-policy blocks git clean -fdx"
OUTPUT=$(cat "$ROOT/tests/fixtures/pretooluse-git-clean-fdx.json" | "$ROOT/hooks/check-git-policy.sh")
if echo "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then
  pass "blocks git clean -fdx"
else
  fail "blocks git clean -fdx"
fi

# ─── New tests: memory-inject.sh with SQLite ─────────────────────

echo ""
echo "=== memory-inject.sh (SQLite) ==="

echo "Test 10: memory-inject works with SQLite"
SQLITE_TMP="$(mktemp -d)"
DB_FILE="$SQLITE_TMP/memory.db"

# Create a minimal SQLite DB with the observations table
python3 -c "
import sqlite3
conn = sqlite3.connect('$DB_FILE')
conn.execute('''CREATE TABLE observations (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    type TEXT DEFAULT 'discovery',
    project TEXT,
    updated_at TEXT DEFAULT '2026-03-30 12:00:00'
)''')
conn.execute('''INSERT INTO observations (title, content, type, project, updated_at)
    VALUES ('Test Convention Found', 'Always use strict mode in TypeScript', 'convention', 'test-project', '2026-03-30 12:00:00')''')
conn.commit()
conn.close()
"

OUTPUT=$(GENTLEMAN_MEMORY_DB="$DB_FILE" PROJECT_NAME="test-project" CLAUDE_PROJECT_DIR="$SQLITE_TMP" "$ROOT/hooks/memory-inject.sh")
rm -rf "$SQLITE_TMP"

if echo "$OUTPUT" | grep -q "Test Convention Found"; then
  pass "reads observations from SQLite DB"
else
  fail "reads observations from SQLite DB (output=$OUTPUT)"
fi

echo "Test 11: memory-inject falls back to files when DB absent"
FALLBACK_TMP="$(mktemp -d)"
mkdir -p "$FALLBACK_TMP/.claude/memory"
echo "Fallback convention: use vitest for testing." > "$FALLBACK_TMP/.claude/memory/conventions.md"

OUTPUT=$(GENTLEMAN_MEMORY_DB="/nonexistent/path/memory.db" CLAUDE_PROJECT_DIR="$FALLBACK_TMP" "$ROOT/hooks/memory-inject.sh")
rm -rf "$FALLBACK_TMP"

if echo "$OUTPUT" | grep -q "vitest"; then
  pass "falls back to file-based memory when DB absent"
else
  fail "falls back to file-based memory when DB absent (output=$OUTPUT)"
fi

# ─── Summary ─────────────────────────────────────────────────────

echo ""
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

echo "All hook tests passed."
