#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // "false"')" = "true" ]; then
  exit 0
fi

fail() {
  echo "{\"ok\": false, \"reason\": \"$1\"}"
  exit 0
}

if [ -n "${LINT_COMMAND:-}" ]; then
  if ! eval "$LINT_COMMAND" > /tmp/stop-verify-lint.log 2>&1; then
    fail "Lint failed: $(tail -5 /tmp/stop-verify-lint.log | tr '\n' ' ')"
  fi
fi

if [ -n "${TEST_COMMAND:-}" ]; then
  if ! eval "$TEST_COMMAND" > /tmp/stop-verify-test.log 2>&1; then
    fail "Tests failed: $(tail -5 /tmp/stop-verify-test.log | tr '\n' ' ')"
  fi
fi

echo '{"ok": true}'
