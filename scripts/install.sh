#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Claude Gentleman Native — One-command installer
# ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLUGIN_NAME="gentleman-native"
INSTALL_DIR="${HOME}/.claude/plugins/${PLUGIN_NAME}"
MEMORY_DIR="${HOME}/.claude/gentleman-memory"

# ── Flags ────────────────────────────────────────────────
DEV_MODE=false
NO_PROJECT=false
UNINSTALL=false

for arg in "$@"; do
  case "$arg" in
    --dev)        DEV_MODE=true ;;
    --no-project) NO_PROJECT=true ;;
    --uninstall)  UNINSTALL=true ;;
    --status)
      exec "${SCRIPT_DIR}/status.sh"
      ;;
    --help|-h)
      echo "Usage: install.sh [--dev] [--no-project] [--uninstall] [--status]"
      echo ""
      echo "  --dev          Use symlinks instead of copies (for plugin developers)"
      echo "  --no-project   Skip bootstrapping the current project"
      echo "  --uninstall    Remove the global plugin installation"
      echo "  --status       Run diagnostic status report and exit"
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg (use --help for usage)"
      exit 1
      ;;
  esac
done

# ── Colors (with fallback for dumb terminals) ───────────
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; }
step()    { echo -e "\n${BOLD}── $* ──${NC}"; }

# ── Uninstall ────────────────────────────────────────────
if [[ "$UNINSTALL" == true ]]; then
  step "Uninstalling ${PLUGIN_NAME}"

  if [[ -e "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    success "Removed ${INSTALL_DIR}"
  else
    warn "Plugin not found at ${INSTALL_DIR} — nothing to remove"
  fi

  echo ""
  read -rp "Also remove memory database at ${MEMORY_DIR}? [y/N] " answer
  if [[ "${answer,,}" == "y" ]]; then
    rm -rf "$MEMORY_DIR"
    success "Removed ${MEMORY_DIR}"
  else
    info "Kept ${MEMORY_DIR}"
  fi

  echo ""
  success "Uninstall complete."
  exit 0
fi

# ── Step 1: Verify environment ───────────────────────────
step "Verifying environment"

MISSING=()

if command -v claude >/dev/null 2>&1; then
  success "claude found: $(claude --version 2>/dev/null || echo 'unknown version')"
else
  MISSING+=("claude")
  error "claude not found — install from https://docs.anthropic.com/en/docs/claude-code"
fi

if command -v python3 >/dev/null 2>&1; then
  success "python3 found: $(python3 --version 2>&1)"
else
  MISSING+=("python3")
  error "python3 not found — install via your package manager (apt install python3 / brew install python3)"
fi

if command -v jq >/dev/null 2>&1; then
  success "jq found: $(jq --version 2>&1)"
else
  MISSING+=("jq")
  error "jq not found — install via your package manager (apt install jq / brew install jq)"
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  error "Missing dependencies: ${MISSING[*]}"
  error "Install them and re-run this script."
  exit 1
fi

# ── Step 2: Check Python sqlite3 FTS5 support ───────────
step "Checking Python sqlite3 FTS5 support"

FTS5_CHECK=$(python3 -c "
import sqlite3, tempfile, os
db_path = os.path.join(tempfile.mkdtemp(), 'fts5_test.db')
try:
    conn = sqlite3.connect(db_path)
    conn.execute('CREATE VIRTUAL TABLE fts5_test USING fts5(content)')
    conn.close()
    os.unlink(db_path)
    print('ok')
except Exception as e:
    try: os.unlink(db_path)
    except: pass
    print(f'fail: {e}')
" 2>&1)

if [[ "$FTS5_CHECK" == "ok" ]]; then
  success "FTS5 is available — full-text memory search enabled"
else
  warn "FTS5 not available (${FTS5_CHECK})"
  warn "Memory search will fall back to LIKE queries — this is fine but slower"
fi

# ── Step 3: Create global directories ───────────────────
step "Creating global directories"

mkdir -p "$MEMORY_DIR"
success "Created ${MEMORY_DIR}"

mkdir -p "${HOME}/.claude/plugins"
success "Ensured ${HOME}/.claude/plugins/ exists"

# ── Step 4: Install plugin globally ─────────────────────
step "Installing plugin to ${INSTALL_DIR}"

PLUGIN_DIRS=(
  ".claude-plugin"
  "agents"
  "skills"
  "hooks"
  "servers"
  "templates"
)

PLUGIN_FILES=(
  "settings.json"
  ".mcp.json"
)

if [[ "$DEV_MODE" == true ]]; then
  # Dev mode: single symlink to the repo root
  info "Dev mode — creating symlink"

  if [[ -L "$INSTALL_DIR" ]]; then
    rm "$INSTALL_DIR"
    info "Removed existing symlink"
  elif [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    info "Removed existing directory (replacing with symlink)"
  fi

  ln -s "$REPO_ROOT" "$INSTALL_DIR"
  success "Symlinked ${INSTALL_DIR} -> ${REPO_ROOT}"

else
  # Copy mode: copy only the essential plugin files
  info "Copy mode — installing files"

  if [[ -L "$INSTALL_DIR" ]]; then
    rm "$INSTALL_DIR"
    info "Removed existing symlink (replacing with copy)"
  fi

  mkdir -p "$INSTALL_DIR"

  for dir in "${PLUGIN_DIRS[@]}"; do
    if [[ -d "${REPO_ROOT}/${dir}" ]]; then
      rm -rf "${INSTALL_DIR}/${dir}"
      cp -r "${REPO_ROOT}/${dir}" "${INSTALL_DIR}/${dir}"
      success "Copied ${dir}/"
    else
      warn "Directory ${dir}/ not found in repo — skipped"
    fi
  done

  for file in "${PLUGIN_FILES[@]}"; do
    if [[ -f "${REPO_ROOT}/${file}" ]]; then
      cp "${REPO_ROOT}/${file}" "${INSTALL_DIR}/${file}"
      success "Copied ${file}"
    else
      warn "File ${file} not found in repo — skipped"
    fi
  done
fi

# Make hook scripts executable
if [[ -d "${INSTALL_DIR}/hooks" ]]; then
  find "${INSTALL_DIR}/hooks" -name "*.sh" -exec chmod +x {} \;
  success "Made hook scripts executable"
fi

# Make server scripts executable
if [[ -d "${INSTALL_DIR}/servers" ]]; then
  find "${INSTALL_DIR}/servers" -name "*.py" -exec chmod +x {} \;
  success "Made server scripts executable"
fi

# ── Step 5: Initialize SQLite database ──────────────────
step "Initializing memory database"

DB_PATH="${MEMORY_DIR}/gentleman.db"

if [[ -f "$DB_PATH" ]]; then
  info "Database already exists at ${DB_PATH} — skipping initialization"
else
  # Try --init flag first; if server doesn't support it, create directory only
  if python3 "${REPO_ROOT}/servers/project_memory_server.py" --init 2>/dev/null; then
    success "Database initialized via server --init"
  else
    info "Server does not support --init yet — database will be created on first run"
    success "Memory directory ready at ${MEMORY_DIR}"
  fi
fi

# ── Step 6: Bootstrap current project (optional) ────────
if [[ "$NO_PROJECT" == false ]]; then
  step "Bootstrapping current project"

  PROJECT_ROOT="${PWD}"

  # Only bootstrap if we're in a project directory (not home, not the plugin repo itself)
  if [[ "$PROJECT_ROOT" == "$HOME" ]]; then
    warn "Running from home directory — skipping project bootstrap"
    warn "Run 'make init' from inside a project to bootstrap it"
  elif [[ "$PROJECT_ROOT" == "$REPO_ROOT" ]]; then
    info "Running from plugin repo — bootstrapping for plugin development"
    "${REPO_ROOT}/scripts/bootstrap-project.sh" "$PROJECT_ROOT"
    success "Plugin repo bootstrapped"
  else
    "${REPO_ROOT}/scripts/bootstrap-project.sh" "$PROJECT_ROOT"
    success "Project bootstrapped at ${PROJECT_ROOT}"
  fi
else
  info "Skipping project bootstrap (--no-project)"
fi

# ── Done ─────────────────────────────────────────────────
step "Installation complete!"

echo ""
echo -e "${GREEN}${BOLD}What was installed:${NC}"
echo "  - Plugin files at ${INSTALL_DIR}"
echo "  - Memory directory at ${MEMORY_DIR}"
if [[ "$NO_PROJECT" == false && "$PWD" != "$HOME" ]]; then
  echo "  - Project bootstrap at ${PWD}/.claude/"
fi

echo ""
echo -e "${GREEN}${BOLD}How to start:${NC}"
echo "  claude --plugin-dir ${INSTALL_DIR}     # Use the installed plugin"
echo "  make dev                                # For plugin development (from repo)"

echo ""
echo -e "${GREEN}${BOLD}Quick verification:${NC}"
echo "  claude -p \"/agents\"                     # Should list the agent team"

if [[ "$DEV_MODE" == true ]]; then
  echo ""
  echo -e "${YELLOW}${BOLD}Dev mode notes:${NC}"
  echo "  Plugin is symlinked — changes to the repo are reflected immediately"
  echo "  Use 'make dev' for the fastest iteration loop"
fi

echo ""
success "You're all set. Enjoy the Gentleman ecosystem."
