# ─────────────────────────────────────────────────────────────────────────────
# Gentleman Native — One-command installer (Windows/PowerShell)
# Usage:
#   irm https://raw.githubusercontent.com/JuaniSarmiento/Ecosistema-Claude/main/setup.ps1 | iex
#   OR: .\setup.ps1  (from cloned repo)
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

function Write-Info  { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Msg) Write-Host "[FAIL]  $Msg" -ForegroundColor Red }
function Stop-Setup  { param([string]$Msg) Write-Fail $Msg; exit 1 }

# ── Resolve Python command ──────────────────────────────────────────────────

$PythonCmd = $null
try { $null = & python3 --version 2>&1; $PythonCmd = "python3" } catch {}
if (-not $PythonCmd) {
    try { $null = & python --version 2>&1; $PythonCmd = "python" } catch {}
}

# ── Step 1: Check dependencies ──────────────────────────────────────────────

Write-Info "Checking dependencies..."

try { $null = & claude --version 2>&1; Write-Ok "claude found" }
catch { Stop-Setup "claude CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code" }

if (-not $PythonCmd) { Stop-Setup "python not found. Install Python 3.10+ from https://python.org" }

$pyVersion = & $PythonCmd --version 2>&1
Write-Ok "$PythonCmd found ($pyVersion)"

$fts5Script = @"
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
"@
try { $fts5Result = & $PythonCmd -c $fts5Script 2>&1 } catch { $fts5Result = "no" }
if ($fts5Result -eq "yes") { Write-Ok "SQLite FTS5 support available" }
else { Write-Warn "FTS5 not available. Search will use LIKE fallback." }

# ── Step 2: Configure marketplace via Python ─────────────────────────────────

Write-Info "Configuring marketplace and plugin..."

$setupAllScript = @"
import json, os, sys

home = os.environ.get('USERPROFILE', os.path.expanduser('~'))

# --- settings.json ---
settings_dir = os.path.join(home, '.claude')
os.makedirs(settings_dir, exist_ok=True)
settings_path = os.path.join(settings_dir, 'settings.json')

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

mp = settings.setdefault('extraKnownMarketplaces', {})
if 'ecosistema-claude' not in mp:
    mp['ecosistema-claude'] = {'source': {'source': 'github', 'repo': 'JuaniSarmiento/Ecosistema-Claude'}}

pl = settings.setdefault('enabledPlugins', {})
pl['claude-gentleman-native@ecosistema-claude'] = True

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print('settings_ok')

# --- memory dir ---
mem_dir = os.path.join(home, '.claude', 'gentleman-memory')
os.makedirs(mem_dir, exist_ok=True)
print('memdir_ok')

# --- .claude.json (MCP server) ---
claude_json_path = os.path.join(home, '.claude.json')
if os.path.exists(claude_json_path):
    with open(claude_json_path) as f:
        content = f.read().strip()
    claude_data = json.loads(content) if content else {}
else:
    claude_data = {}

servers = claude_data.setdefault('mcpServers', {})
server_py = os.path.join(home, '.claude', 'plugins', 'marketplaces', 'ecosistema-claude', 'plugin', 'servers', 'project_memory_server.py')
server_py_fwd = server_py.replace('\\\\', '/')

if 'gentleman-memory' not in servers:
    servers['gentleman-memory'] = {
        'type': 'stdio',
        'command': 'python',
        'args': [server_py_fwd],
        'env': {}
    }
elif servers['gentleman-memory'].get('args', [''])[0] != server_py_fwd:
    servers['gentleman-memory']['args'] = [server_py_fwd]

with open(claude_json_path, 'w') as f:
    json.dump(claude_data, f, indent=2)

print('mcp_ok')

# --- Init DB if server exists ---
if os.path.exists(server_py):
    import subprocess
    r = subprocess.run([sys.executable, server_py, '--init'], capture_output=True, text=True)
    print('db_ok' if r.returncode == 0 else 'db_skip')
else:
    print('db_skip')
"@

$results = & $PythonCmd -c $setupAllScript 2>&1

$resultText = $results -join " "

if ($resultText -match "settings_ok") { Write-Ok "Marketplace registered and plugin enabled" }
else { Stop-Setup "Failed to configure marketplace" }

if ($resultText -match "memdir_ok") { Write-Ok "Memory directory ready" }

if ($resultText -match "mcp_ok") { Write-Ok "MCP server configured in ~/.claude.json" }
else { Stop-Setup "Failed to configure MCP server" }

if ($resultText -match "db_ok") { Write-Ok "Database initialized" }
else { Write-Warn "Server not downloaded yet. DB will init on first use." }

# ── Success ─────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "+--------------------------------------------------+" -ForegroundColor Green
Write-Host "|   Gentleman Native -- Setup Complete              |" -ForegroundColor Green
Write-Host "+--------------------------------------------------+" -ForegroundColor Green
Write-Host "|                                                   |" -ForegroundColor Green
Write-Host "|  Next: Open Claude and run /reload-plugins        |" -ForegroundColor Green
Write-Host "|                                                   |" -ForegroundColor Green
Write-Host "+--------------------------------------------------+" -ForegroundColor Green
Write-Host ""
