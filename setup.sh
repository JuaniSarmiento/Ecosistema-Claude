#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Gentleman Native — One-command installer
# Usage:
#   curl -sSL https://raw.githubusercontent.com/JuaniSarmiento/Ecosistema-Claude/main/setup.sh | bash
#   OR: bash setup.sh  (from cloned repo)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors (with dumb terminal fallback) ─────────────────────────────────────

if [[ "${TERM:-dumb}" != "dumb" ]] && command -v tput &>/dev/null && tput colors &>/dev/null; then
  GREEN=$(tput setaf 2)
  RED=$(tput setaf 1)
  YELLOW=$(tput setaf 3)
  CYAN=$(tput setaf 6)
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
else
  GREEN="" RED="" YELLOW="" CYAN="" BOLD="" RESET=""
fi

info()  { printf "%s[INFO]%s  %s\n" "$CYAN"  "$RESET" "$1"; }
ok()    { printf "%s[OK]%s    %s\n" "$GREEN"  "$RESET" "$1"; }
warn()  { printf "%s[WARN]%s  %s\n" "$YELLOW" "$RESET" "$1"; }
fail()  { printf "%s[FAIL]%s  %s\n" "$RED"    "$RESET" "$1"; }
die()   { fail "$1"; exit 1; }

# ── Step 1: Check dependencies ───────────────────────────────────────────────

info "Checking dependencies..."

command -v claude &>/dev/null || die "claude CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code"
ok "claude found"

command -v python3 &>/dev/null || die "python3 not found. Install Python 3.10+"
ok "python3 found ($(python3 --version 2>&1))"

command -v jq &>/dev/null || die "jq not found. Install: https://jqlang.github.io/jq/download/"
ok "jq found"

# Check FTS5 support
FTS5_OK=$(python3 -c "
import sqlite3, tempfile, os
db = os.path.join(tempfile.mkdtemp(), 'test.db')
conn = sqlite3.connect(db)
try:
    conn.execute('CREATE VIRTUAL TABLE t USING fts5(c)')
    print('yes')
except Exception:
    print('no')
finally:
    conn.close()
    os.unlink(db)
" 2>/dev/null || echo "no")

if [[ "$FTS5_OK" == "yes" ]]; then
  ok "SQLite FTS5 support available"
else
  warn "SQLite FTS5 not available. Memory search will use LIKE fallback (slower but functional)."
fi

# ── Step 2: Add marketplace to ~/.claude/settings.json ────────────────────────

SETTINGS_FILE="$HOME/.claude/settings.json"
info "Configuring marketplace in $SETTINGS_FILE..."

mkdir -p "$HOME/.claude"

python3 -c "
import json, os, sys

path = os.path.expanduser('~/.claude/settings.json')

# Read existing or start fresh
if os.path.exists(path):
    with open(path, 'r') as f:
        data = json.load(f)
else:
    data = {}

changed = False

# Add marketplace
marketplaces = data.setdefault('extraKnownMarketplaces', {})
if 'ecosistema-claude' not in marketplaces:
    marketplaces['ecosistema-claude'] = {'source': {'source': 'github', 'repo': 'JuaniSarmiento/Ecosistema-Claude'}}
    changed = True

# Enable plugin
plugins = data.setdefault('enabledPlugins', {})
entry = 'claude-gentleman-native@ecosistema-claude'
if entry not in plugins:
    plugins[entry] = True
    changed = True

# Write back
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

if changed:
    print('updated')
else:
    print('already_configured')
"

SETTINGS_RESULT=$(python3 -c "
import json, os
path = os.path.expanduser('~/.claude/settings.json')
data = json.load(open(path))
mp = 'ecosistema-claude' in data.get('extraKnownMarketplaces', {})
pl = 'claude-gentleman-native@ecosistema-claude' in data.get('enabledPlugins', {})
print('ok' if mp and pl else 'fail')
")

if [[ "$SETTINGS_RESULT" == "ok" ]]; then
  ok "Marketplace registered and plugin enabled"
else
  die "Failed to update settings.json"
fi

# ── Step 3: Force marketplace download ────────────────────────────────────────

info "Attempting to download marketplace plugin..."

PLUGIN_DOWNLOADED=false

if claude plugins update ecosistema-claude &>/dev/null 2>&1; then
  ok "Plugin downloaded via 'claude plugins update'"
  PLUGIN_DOWNLOADED=true
elif claude plugin update &>/dev/null 2>&1; then
  ok "Plugin downloaded via 'claude plugin update'"
  PLUGIN_DOWNLOADED=true
else
  warn "Could not force plugin download. Claude will download it on next start."
fi

# ── Step 4: Create memory database directory ──────────────────────────────────

MEMORY_DIR="$HOME/.claude/gentleman-memory"
info "Creating memory directory..."
mkdir -p "$MEMORY_DIR"
ok "Memory directory ready: $MEMORY_DIR"

# ── Step 5: Resolve server path & add MCP server to ~/.claude.json ────────────

info "Locating memory server..."

MARKETPLACE_PATH="$HOME/.claude/plugins/marketplaces/ecosistema-claude/plugin/servers/project_memory_server.py"
LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)/plugin/servers/project_memory_server.py"

SERVER_PATH=""

if [[ -f "$MARKETPLACE_PATH" ]]; then
  SERVER_PATH="$MARKETPLACE_PATH"
  ok "Server found (marketplace install): $SERVER_PATH"
elif [[ -f "$LOCAL_PATH" ]]; then
  SERVER_PATH="$LOCAL_PATH"
  ok "Server found (local repo): $SERVER_PATH"
else
  # If plugin wasn't downloaded yet, use the marketplace path as target
  # (it will exist after Claude downloads the plugin on next start)
  SERVER_PATH="$MARKETPLACE_PATH"
  warn "Server not found yet. Using expected marketplace path: $SERVER_PATH"
  warn "The server will be available after Claude downloads the plugin on next start."
fi

info "Configuring MCP server in ~/.claude.json..."

CLAUDE_JSON="$HOME/.claude.json"

python3 -c "
import json, os, sys

path = os.path.expanduser('~/.claude.json')
server_path = sys.argv[1]

# Read existing or start fresh
if os.path.exists(path):
    with open(path, 'r') as f:
        content = f.read().strip()
    data = json.loads(content) if content else {}
else:
    data = {}

servers = data.setdefault('mcpServers', {})

if 'gentleman-memory' not in servers:
    servers['gentleman-memory'] = {
        'type': 'stdio',
        'command': 'python3',
        'args': [server_path],
        'env': {}
    }
    status = 'added'
else:
    # Update path if it changed
    existing_args = servers['gentleman-memory'].get('args', [])
    if not existing_args or existing_args[0] != server_path:
        servers['gentleman-memory']['args'] = [server_path]
        status = 'updated'
    else:
        status = 'already_configured'

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

print(status)
" "$SERVER_PATH"

MCP_RESULT=$(python3 -c "
import json, os
path = os.path.expanduser('~/.claude.json')
if not os.path.exists(path):
    print('fail')
else:
    data = json.load(open(path))
    has_server = 'gentleman-memory' in data.get('mcpServers', {})
    print('ok' if has_server else 'fail')
")

if [[ "$MCP_RESULT" == "ok" ]]; then
  ok "MCP server configured in ~/.claude.json"
else
  die "Failed to configure MCP server in ~/.claude.json"
fi

# ── Step 6: Initialize the database ──────────────────────────────────────────

info "Initializing memory database..."

if [[ -f "$SERVER_PATH" ]]; then
  INIT_OUTPUT=$(python3 "$SERVER_PATH" --init 2>&1)
  ok "$INIT_OUTPUT"
else
  warn "Server script not available yet. Database will be initialized on first use."
fi

# ── Step 7: Success ──────────────────────────────────────────────────────────

echo ""
echo "${BOLD}${GREEN}"
cat <<'BANNER'
+--------------------------------------------------+
|   Gentleman Native -- Setup Complete              |
+--------------------------------------------------+
|                                                   |
|  + Marketplace registered                         |
|  + Plugin enabled                                 |
|  + Memory server configured                       |
|  + Database initialized                           |
|                                                   |
|  Next: Open Claude and run /reload-plugins        |
|                                                   |
+--------------------------------------------------+
BANNER
echo "${RESET}"

info "If this is your first time, you may need to restart Claude for changes to take effect."
