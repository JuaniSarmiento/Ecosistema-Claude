#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Claude Gentleman Native — Status / Diagnostic Report
# ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLUGIN_NAME="gentleman-native"
INSTALL_DIR="${HOME}/.claude/plugins/${PLUGIN_NAME}"
MEMORY_DIR="${HOME}/.claude/gentleman-memory"
DB_PATH="${MEMORY_DIR}/memory.db"

# ── Exit codes ──────────────────────────────────────────
EXIT_OK=0
EXIT_PLUGIN_MISSING=1
EXIT_DEPS_MISSING=2

FINAL_EXIT=$EXIT_OK

# ── Colors & symbols (with fallback for dumb terminals) ─
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  NC='\033[0m'
  SYM_OK='✓'
  SYM_FAIL='✗'
  SYM_WARN='!'
else
  RED='' GREEN='' YELLOW='' BOLD='' NC=''
  SYM_OK='[OK]'
  SYM_FAIL='[FAIL]'
  SYM_WARN='[WARN]'
fi

BOX_WIDTH=50

# ── Output helpers ──────────────────────────────────────
box_top()    { echo -e "${BOLD}╔$(printf '═%.0s' $(seq 1 $BOX_WIDTH))╗${NC}"; }
box_mid()    { echo -e "${BOLD}╠$(printf '═%.0s' $(seq 1 $BOX_WIDTH))╣${NC}"; }
box_bottom() { echo -e "${BOLD}╚$(printf '═%.0s' $(seq 1 $BOX_WIDTH))╝${NC}"; }
box_empty()  { printf "${BOLD}║${NC}%-${BOX_WIDTH}s${BOLD}║${NC}\n" ""; }
box_title()  { printf "${BOLD}║${NC}   %-$(( BOX_WIDTH - 3 ))s${BOLD}║${NC}\n" "$1"; }

check_ok() {
  printf "${BOLD}║${NC}  ${GREEN}${SYM_OK}${NC} %-$(( BOX_WIDTH - 4 ))s${BOLD}║${NC}\n" "$1"
}

check_fail() {
  printf "${BOLD}║${NC}  ${RED}${SYM_FAIL}${NC} %-$(( BOX_WIDTH - 4 ))s${BOLD}║${NC}\n" "$1"
}

check_warn() {
  printf "${BOLD}║${NC}  ${YELLOW}${SYM_WARN}${NC} %-$(( BOX_WIDTH - 4 ))s${BOLD}║${NC}\n" "$1"
}

section_header() {
  box_empty
  box_title "$1"
}

# ── Dependency checks ──────────────────────────────────
deps_ok=true

get_version() {
  local cmd="$1"
  case "$cmd" in
    claude)  claude --version 2>/dev/null | head -1 | awk '{print $1}' || echo "unknown" ;;
    python3) python3 --version 2>&1 | awk '{print $2}' ;;
    jq)      jq --version 2>&1 | sed 's/jq-//' ;;
  esac
}

check_dep() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver="$(get_version "$cmd")"
    check_ok "$cmd ($ver)"
  else
    check_fail "$cmd not found"
    deps_ok=false
  fi
}

check_fts5() {
  local result
  result=$(python3 -c "
import sqlite3, tempfile, os
db = os.path.join(tempfile.mkdtemp(), 'test.db')
try:
    c = sqlite3.connect(db)
    c.execute('CREATE VIRTUAL TABLE t USING fts5(x)')
    c.close(); os.unlink(db)
    print('ok')
except Exception:
    try: os.unlink(db)
    except: pass
    print('fail')
" 2>&1)
  if [[ "$result" == "ok" ]]; then
    check_ok "FTS5 support"
  else
    check_warn "FTS5 not available (fallback to LIKE)"
  fi
}

# ── Plugin checks ──────────────────────────────────────
plugin_installed=false

check_plugin() {
  if [[ ! -e "$INSTALL_DIR" ]]; then
    check_fail "Not installed"
    FINAL_EXIT=$EXIT_PLUGIN_MISSING
    return
  fi

  plugin_installed=true
  check_ok "Installed at ~/.claude/plugins/..."

  if [[ -L "$INSTALL_DIR" ]]; then
    check_ok "Mode: dev (symlink)"
  else
    check_ok "Mode: production (copy)"
  fi

  # Count agents (.md files in agents/)
  local agent_dir="${INSTALL_DIR}/agents"
  if [[ -d "$agent_dir" ]]; then
    local agent_count
    agent_count=$(find "$agent_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
    check_ok "Agents: ${agent_count} found"
  else
    check_fail "agents/ directory missing"
  fi

  # Count skills (SKILL.md files recursively in skills/)
  local skills_dir="${INSTALL_DIR}/skills"
  if [[ -d "$skills_dir" ]]; then
    local skill_count
    skill_count=$(find "$skills_dir" -name "SKILL.md" -type f 2>/dev/null | wc -l)
    check_ok "Skills: ${skill_count} found"
  else
    check_fail "skills/ directory missing"
  fi

  # Count hooks from hooks.json
  local hooks_json="${INSTALL_DIR}/hooks/hooks.json"
  if [[ -f "$hooks_json" ]]; then
    local hook_count
    hook_count=$(jq '[.hooks | to_entries[] | .value[] | .hooks[]? ] | length' "$hooks_json" 2>/dev/null || echo "0")
    check_ok "Hooks: ${hook_count} registered"
  else
    check_fail "hooks/hooks.json missing"
  fi

  # Check other expected dirs
  for dir in hooks servers; do
    if [[ -d "${INSTALL_DIR}/${dir}" ]]; then
      :  # already checked or implicitly fine
    else
      check_warn "${dir}/ directory missing"
    fi
  done
}

# ── Memory checks ──────────────────────────────────────
check_memory() {
  if [[ ! -f "$DB_PATH" ]]; then
    check_warn "Database not found"
    return
  fi

  # Database size
  local db_size
  if [[ "$(uname)" == "Darwin" ]]; then
    db_size=$(stat -f%z "$DB_PATH" 2>/dev/null || echo "0")
  else
    db_size=$(stat -c%s "$DB_PATH" 2>/dev/null || echo "0")
  fi

  local db_size_human
  if (( db_size >= 1048576 )); then
    db_size_human="$(awk "BEGIN {printf \"%.1f MB\", ${db_size}/1048576}")"
  elif (( db_size >= 1024 )); then
    db_size_human="$(awk "BEGIN {printf \"%.1f KB\", ${db_size}/1024}")"
  else
    db_size_human="${db_size} B"
  fi
  check_ok "Database exists (${db_size_human})"

  # Count observations and sessions via Python
  local counts
  counts=$(python3 -c "
import sqlite3, sys, json
try:
    conn = sqlite3.connect('${DB_PATH}')
    cur = conn.cursor()
    obs = 0; sess = 0
    try:
        cur.execute('SELECT COUNT(*) FROM observations')
        obs = cur.fetchone()[0]
    except: pass
    try:
        cur.execute('SELECT COUNT(*) FROM sessions')
        sess = cur.fetchone()[0]
    except: pass
    conn.close()
    print(json.dumps({'obs': obs, 'sess': sess}))
except Exception as e:
    print(json.dumps({'obs': -1, 'sess': -1, 'error': str(e)}))
" 2>/dev/null || echo '{"obs":-1,"sess":-1}')

  local obs sess
  obs=$(echo "$counts" | jq -r '.obs')
  sess=$(echo "$counts" | jq -r '.sess')

  if [[ "$obs" == "-1" ]]; then
    check_warn "Could not query database"
  else
    check_ok "${obs} observations"
    check_ok "${sess} sessions"
  fi
}

# ── Current project checks ─────────────────────────────
check_project() {
  local project_root="$PWD"
  local project_name
  project_name="$(basename "$project_root")"

  if [[ "$project_root" == "$HOME" ]]; then
    check_warn "In home directory — no project context"
    return
  fi

  section_header "Current Project (${project_name})"

  if [[ -d "${project_root}/.claude/memory" ]]; then
    check_ok ".claude/memory/ exists"
  else
    check_fail ".claude/memory/ missing (run make init)"
  fi

  if [[ -d "${project_root}/.claude/specs" ]]; then
    check_ok ".claude/specs/ exists"
  else
    check_fail ".claude/specs/ missing (run make init)"
  fi

  if [[ -f "${project_root}/AGENTS.md" ]]; then
    check_ok "AGENTS.md exists"
  else
    check_fail "AGENTS.md missing (run make init)"
  fi

  # Count project observations in DB
  if [[ -f "$DB_PATH" ]]; then
    local proj_obs
    proj_obs=$(python3 -c "
import sqlite3, json
try:
    conn = sqlite3.connect('${DB_PATH}')
    cur = conn.cursor()
    try:
        cur.execute('SELECT COUNT(*) FROM observations WHERE project = ?', ('${project_name}',))
        count = cur.fetchone()[0]
    except:
        count = 0
    conn.close()
    print(count)
except:
    print(0)
" 2>/dev/null || echo "0")
    check_ok "${proj_obs} observations in memory"
  fi
}

# ── Main ────────────────────────────────────────────────

box_top
box_title "Gentleman Native — Status Report"
box_mid

section_header "Dependencies"
check_dep "claude"
check_dep "python3"
check_dep "jq"

if [[ "$deps_ok" == false ]]; then
  FINAL_EXIT=$EXIT_DEPS_MISSING
fi

# FTS5 only makes sense if python3 is available
if command -v python3 >/dev/null 2>&1; then
  check_fts5
fi

section_header "Plugin"
check_plugin

section_header "Memory"
check_memory

check_project

box_empty
box_bottom

exit $FINAL_EXIT
