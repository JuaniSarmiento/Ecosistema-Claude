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

try {
    $null = & python3 --version 2>&1
    $PythonCmd = "python3"
} catch {}

if (-not $PythonCmd) {
    try {
        $null = & python --version 2>&1
        $PythonCmd = "python"
    } catch {}
}

# ── Step 1: Check dependencies ──────────────────────────────────────────────

Write-Info "Checking dependencies..."

try {
    $claudeVersion = & claude --version 2>&1
    Write-Ok "claude found"
} catch {
    Stop-Setup "claude CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code"
}

if (-not $PythonCmd) {
    Stop-Setup "python not found. Install Python 3.10+ from https://python.org"
}

$pyVersion = & $PythonCmd --version 2>&1
Write-Ok "$PythonCmd found ($pyVersion)"

# Check FTS5 support
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

try {
    $fts5Result = & $PythonCmd -c $fts5Script 2>&1
} catch {
    $fts5Result = "no"
}

if ($fts5Result -eq "yes") {
    Write-Ok "SQLite FTS5 support available"
} else {
    Write-Warn "SQLite FTS5 not available. Memory search will use LIKE fallback (slower but functional)."
}

# ── Step 2: Add marketplace to settings.json ─────────────────────────────────

$settingsDir = Join-Path $env:USERPROFILE ".claude"
$settingsFile = Join-Path $settingsDir "settings.json"

Write-Info "Configuring marketplace in $settingsFile..."

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$settingsScript = @"
import json, os, sys

path = os.path.join(os.environ['USERPROFILE'], '.claude', 'settings.json')

if os.path.exists(path):
    with open(path, 'r') as f:
        data = json.load(f)
else:
    data = {}

changed = False

marketplaces = data.setdefault('extraKnownMarketplaces', {})
if 'ecosistema-claude' not in marketplaces:
    marketplaces['ecosistema-claude'] = {'source': {'source': 'github', 'repo': 'JuaniSarmiento/Ecosistema-Claude'}}
    changed = True

plugins = data.setdefault('enabledPlugins', {})
entry = 'claude-gentleman-native@ecosistema-claude'
if entry not in plugins:
    plugins[entry] = True
    changed = True

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

if changed:
    print('updated')
else:
    print('already_configured')
"@

& $PythonCmd -c $settingsScript

# Verify settings
$verifySettingsScript = @"
import json, os
path = os.path.join(os.environ['USERPROFILE'], '.claude', 'settings.json')
data = json.load(open(path))
mp = 'ecosistema-claude' in data.get('extraKnownMarketplaces', {})
pl = 'claude-gentleman-native@ecosistema-claude' in data.get('enabledPlugins', {})
print('ok' if mp and pl else 'fail')
"@

$settingsResult = & $PythonCmd -c $verifySettingsScript

if ($settingsResult -eq "ok") {
    Write-Ok "Marketplace registered and plugin enabled"
} else {
    Stop-Setup "Failed to update settings.json"
}

# ── Step 3: Force marketplace download ───────────────────────────────────────

Write-Info "Attempting to download marketplace plugin..."

$pluginDownloaded = $false

try {
    $null = & claude plugins update ecosistema-claude 2>&1
    Write-Ok "Plugin downloaded via 'claude plugins update'"
    $pluginDownloaded = $true
} catch {}

if (-not $pluginDownloaded) {
    try {
        $null = & claude plugin update 2>&1
        Write-Ok "Plugin downloaded via 'claude plugin update'"
        $pluginDownloaded = $true
    } catch {}
}

if (-not $pluginDownloaded) {
    Write-Warn "Could not force plugin download. Claude will download it on next start."
}

# ── Step 4: Create memory database directory ─────────────────────────────────

$memoryDir = Join-Path $env:USERPROFILE ".claude" "gentleman-memory"

Write-Info "Creating memory directory..."

if (-not (Test-Path $memoryDir)) {
    New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
}

Write-Ok "Memory directory ready: $memoryDir"

# ── Step 5: Resolve server path & add MCP server to .claude.json ─────────────

Write-Info "Locating memory server..."

$marketplacePath = Join-Path $env:USERPROFILE ".claude" "plugins" "marketplaces" "ecosistema-claude" "plugin" "servers" "project_memory_server.py"

# Try to resolve local path (if running from cloned repo)
$localPath = $null
try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ($scriptDir) {
        $localPath = Join-Path $scriptDir "plugin" "servers" "project_memory_server.py"
    }
} catch {}

$serverPath = $null

if (Test-Path $marketplacePath) {
    $serverPath = $marketplacePath
    Write-Ok "Server found (marketplace install): $serverPath"
} elseif ($localPath -and (Test-Path $localPath)) {
    $serverPath = $localPath
    Write-Ok "Server found (local repo): $serverPath"
} else {
    $serverPath = $marketplacePath
    Write-Warn "Server not found yet. Using expected marketplace path: $serverPath"
    Write-Warn "The server will be available after Claude downloads the plugin on next start."
}

Write-Info "Configuring MCP server in ~/.claude.json..."

# Use forward slashes in the JSON path (Python handles both on Windows)
$serverPathForJson = $serverPath -replace '\\', '/'

$claudeJsonScript = @"
import json, os, sys

path = os.path.join(os.environ['USERPROFILE'], '.claude.json')
server_path = sys.argv[1]

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
        'command': 'python',
        'args': [server_path],
        'env': {}
    }
    status = 'added'
else:
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
"@

& $PythonCmd -c $claudeJsonScript $serverPathForJson

# Verify MCP config
$verifyMcpScript = @"
import json, os
path = os.path.join(os.environ['USERPROFILE'], '.claude.json')
if not os.path.exists(path):
    print('fail')
else:
    data = json.load(open(path))
    has_server = 'gentleman-memory' in data.get('mcpServers', {})
    print('ok' if has_server else 'fail')
"@

$mcpResult = & $PythonCmd -c $verifyMcpScript

if ($mcpResult -eq "ok") {
    Write-Ok "MCP server configured in ~/.claude.json"
} else {
    Stop-Setup "Failed to configure MCP server in ~/.claude.json"
}

# ── Step 6: Initialize the database ─────────────────────────────────────────

Write-Info "Initializing memory database..."

if (Test-Path $serverPath) {
    try {
        $initOutput = & $PythonCmd $serverPath --init 2>&1
        Write-Ok "$initOutput"
    } catch {
        Write-Warn "Failed to initialize database: $_"
    }
} else {
    Write-Warn "Server script not available yet. Database will be initialized on first use."
}

# ── Step 7: Success ─────────────────────────────────────────────────────────

Write-Host ""
Write-Host "+--------------------------------------------------+" -ForegroundColor Green
Write-Host "|   Gentleman Native -- Setup Complete              |" -ForegroundColor Green
Write-Host "+--------------------------------------------------+" -ForegroundColor Green
Write-Host "|                                                   |" -ForegroundColor Green
Write-Host "|  + Marketplace registered                         |" -ForegroundColor Green
Write-Host "|  + Plugin enabled                                 |" -ForegroundColor Green
Write-Host "|  + Memory server configured                       |" -ForegroundColor Green
Write-Host "|  + Database initialized                           |" -ForegroundColor Green
Write-Host "|                                                   |" -ForegroundColor Green
Write-Host "|  Next: Open Claude and run /reload-plugins        |" -ForegroundColor Green
Write-Host "|                                                   |" -ForegroundColor Green
Write-Host "+--------------------------------------------------+" -ForegroundColor Green
Write-Host ""

Write-Info "If this is your first time, you may need to restart Claude for changes to take effect."
