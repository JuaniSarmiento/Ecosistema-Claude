#!/usr/bin/env bash
set -euo pipefail

# Detect cp flag for no-clobber (--update=none is preferred but requires coreutils 9.x+)
if cp --update=none /dev/null /dev/null 2>/dev/null; then
    CP_NO_CLOBBER="cp --update=none"
else
    CP_NO_CLOBBER="cp -n"
fi

PROJECT_ROOT="${1:-$PWD}"

mkdir -p "${PROJECT_ROOT}/.claude/memory"
mkdir -p "${PROJECT_ROOT}/.claude/specs"

$CP_NO_CLOBBER "$(dirname "$0")/../templates/memory/conventions.md" "${PROJECT_ROOT}/.claude/memory/conventions.md"
$CP_NO_CLOBBER "$(dirname "$0")/../templates/memory/current-work.md" "${PROJECT_ROOT}/.claude/memory/current-work.md"
$CP_NO_CLOBBER "$(dirname "$0")/../templates/memory/decisions.md" "${PROJECT_ROOT}/.claude/memory/decisions.md"
$CP_NO_CLOBBER "$(dirname "$0")/../templates/memory/open-questions.md" "${PROJECT_ROOT}/.claude/memory/open-questions.md"

$CP_NO_CLOBBER "$(dirname "$0")/../templates/specs/spec-template.md" "${PROJECT_ROOT}/.claude/specs/spec-template.md"
$CP_NO_CLOBBER "$(dirname "$0")/../templates/specs/design-template.md" "${PROJECT_ROOT}/.claude/specs/design-template.md"
$CP_NO_CLOBBER "$(dirname "$0")/../templates/specs/tasks-template.md" "${PROJECT_ROOT}/.claude/specs/tasks-template.md"

if [ ! -f "${PROJECT_ROOT}/AGENTS.md" ]; then
  cp "$(dirname "$0")/../templates/rules/AGENTS.md" "${PROJECT_ROOT}/AGENTS.md"
fi

echo "Proyecto inicializado:"
echo "  - .claude/memory/"
echo "  - .claude/specs/"
echo "  - AGENTS.md"
