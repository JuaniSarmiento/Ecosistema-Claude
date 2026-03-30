#!/usr/bin/env python3
"""
Gentleman Memory MCP Server — SQLite+FTS5 persistent memory for Claude Code.

JSON-RPC 2.0 over stdio. Provides 7 tools: mem_save, mem_search, mem_get,
mem_update, mem_context, mem_session_start, mem_session_summary.

Database: ~/.claude/gentleman-memory/memory.db (WAL mode, FTS5 full-text search).
Auto-migrates from legacy .claude/memory/*.md files on first run.
Python 3 stdlib only — no external dependencies.
"""

import json
import os
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from glob import glob
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DB_DIR = Path.home() / ".claude" / "gentleman-memory"
DB_PATH = DB_DIR / "memory.db"
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
LEGACY_MEMORY_DIR = Path(PROJECT_DIR) / ".claude" / "memory"

# ---------------------------------------------------------------------------
# Database setup
# ---------------------------------------------------------------------------

HAS_FTS5 = False


def _check_fts5(conn: sqlite3.Connection) -> bool:
    """Return True if FTS5 is available."""
    try:
        conn.execute("CREATE VIRTUAL TABLE _fts5_check USING fts5(x)")
        conn.execute("DROP TABLE _fts5_check")
        return True
    except Exception:
        return False


def _init_db() -> sqlite3.Connection:
    """Create/open database, apply schema, return connection."""
    global HAS_FTS5

    DB_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH), isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")

    HAS_FTS5 = _check_fts5(conn)

    # Core tables
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS observations (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT NOT NULL,
            content     TEXT NOT NULL,
            type        TEXT CHECK(type IN (
                'bugfix','decision','architecture','discovery',
                'pattern','config','preference','convention','session_summary'
            )),
            scope       TEXT DEFAULT 'project' CHECK(scope IN ('project','personal')),
            topic_key   TEXT,
            project     TEXT,
            session_id  TEXT,
            created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id          TEXT PRIMARY KEY,
            project     TEXT,
            goal        TEXT,
            summary     TEXT,
            started_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
            ended_at    DATETIME
        );
    """)

    # Unique partial index for topic_key upsert
    try:
        conn.execute("""
            CREATE UNIQUE INDEX idx_topic_project
            ON observations(topic_key, project)
            WHERE topic_key IS NOT NULL
        """)
    except sqlite3.OperationalError:
        pass  # already exists

    # FTS5 virtual table + sync triggers
    if HAS_FTS5:
        try:
            conn.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS observations_fts
                USING fts5(
                    title, content, type, topic_key,
                    content='observations', content_rowid='id'
                )
            """)
        except sqlite3.OperationalError:
            HAS_FTS5 = False

    if HAS_FTS5:
        # Triggers to keep FTS in sync
        for trigger_sql in [
            """
            CREATE TRIGGER IF NOT EXISTS observations_ai AFTER INSERT ON observations BEGIN
                INSERT INTO observations_fts(rowid, title, content, type, topic_key)
                VALUES (new.id, new.title, new.content, new.type, new.topic_key);
            END
            """,
            """
            CREATE TRIGGER IF NOT EXISTS observations_ad AFTER DELETE ON observations BEGIN
                INSERT INTO observations_fts(observations_fts, rowid, title, content, type, topic_key)
                VALUES ('delete', old.id, old.title, old.content, old.type, old.topic_key);
            END
            """,
            """
            CREATE TRIGGER IF NOT EXISTS observations_au AFTER UPDATE ON observations BEGIN
                INSERT INTO observations_fts(observations_fts, rowid, title, content, type, topic_key)
                VALUES ('delete', old.id, old.title, old.content, old.type, old.topic_key);
                INSERT INTO observations_fts(rowid, title, content, type, topic_key)
                VALUES (new.id, new.title, new.content, new.type, new.topic_key);
            END
            """,
        ]:
            try:
                conn.execute(trigger_sql)
            except sqlite3.OperationalError:
                pass  # already exists

    if not HAS_FTS5:
        _log("FTS5 not available — falling back to LIKE-based search")

    return conn


# ---------------------------------------------------------------------------
# Migration from legacy .claude/memory/*.md
# ---------------------------------------------------------------------------

def _migrate_legacy(conn: sqlite3.Connection) -> None:
    """Import .claude/memory/*.md files if DB has no observations for this project."""
    if not LEGACY_MEMORY_DIR.is_dir():
        return

    md_files = sorted(glob(str(LEGACY_MEMORY_DIR / "*.md")))
    if not md_files:
        return

    project = PROJECT_DIR
    row = conn.execute(
        "SELECT COUNT(*) as c FROM observations WHERE project = ?", (project,)
    ).fetchone()
    if row["c"] > 0:
        return  # already migrated

    count = 0
    for fpath in md_files:
        p = Path(fpath)
        title = p.stem
        try:
            content = p.read_text(encoding="utf-8")
        except Exception as e:
            _log(f"Migration: failed to read {fpath}: {e}")
            continue
        conn.execute(
            """INSERT INTO observations (title, content, type, scope, topic_key, project)
               VALUES (?, ?, 'convention', 'project', ?, ?)""",
            (title, content, f"legacy/{title}", project),
        )
        count += 1

    if count:
        _log(f"Migrated {count} legacy memory files from {LEGACY_MEMORY_DIR}")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _log(msg: str) -> None:
    """Write diagnostic message to stderr (never stdout)."""
    sys.stderr.write(f"[gentleman-memory] {msg}\n")
    sys.stderr.flush()


def _send(msg: dict) -> None:
    """Write JSON-RPC response to stdout."""
    sys.stdout.write(json.dumps(msg, default=str) + "\n")
    sys.stdout.flush()


def _ok(rid, result):
    return {"jsonrpc": "2.0", "id": rid, "result": result}


def _text(rid, text):
    return _ok(rid, {"content": [{"type": "text", "text": text if isinstance(text, str) else json.dumps(text, default=str, ensure_ascii=False, indent=2)}]})


def _error(rid, code, message):
    return {"jsonrpc": "2.0", "id": rid, "error": {"code": code, "message": message}}


def _now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _row_to_dict(row: sqlite3.Row) -> dict:
    return dict(row)


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

def tool_mem_save(conn: sqlite3.Connection, args: dict) -> dict:
    title = args.get("title", "").strip()
    content = args.get("content", "").strip()
    obs_type = args.get("type")
    scope = args.get("scope", "project")
    topic_key = args.get("topic_key")
    project = args.get("project")
    session_id = args.get("session_id")

    if not title or not content:
        return {"error": "title and content are required"}

    now = _now()

    # Upsert: if topic_key provided and exists for same project, UPDATE
    if topic_key and project:
        existing = conn.execute(
            "SELECT id FROM observations WHERE topic_key = ? AND project = ?",
            (topic_key, project),
        ).fetchone()
        if existing:
            conn.execute(
                """UPDATE observations
                   SET title = ?, content = ?, type = COALESCE(?, type),
                       scope = ?, session_id = COALESCE(?, session_id),
                       updated_at = ?
                   WHERE id = ?""",
                (title, content, obs_type, scope, session_id, now, existing["id"]),
            )
            return {"id": existing["id"], "action": "updated", "topic_key": topic_key}

    cur = conn.execute(
        """INSERT INTO observations (title, content, type, scope, topic_key, project, session_id, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (title, content, obs_type, scope, topic_key, project, session_id, now, now),
    )
    return {"id": cur.lastrowid, "action": "created", "topic_key": topic_key}


def tool_mem_search(conn: sqlite3.Connection, args: dict) -> dict:
    query = args.get("query", "").strip()
    project = args.get("project")
    obs_type = args.get("type")
    scope = args.get("scope")
    limit = int(args.get("limit", 10))

    if not query:
        return {"error": "query is required"}

    results = []

    if HAS_FTS5:
        # Sanitize query for FTS5: wrap each token in double quotes to avoid syntax errors
        tokens = query.split()
        fts_query = " ".join(f'"{t}"' for t in tokens if t)

        sql = """
            SELECT o.id, o.title, SUBSTR(o.content, 1, 200) as snippet,
                   o.type, o.topic_key, o.scope, o.project, o.updated_at
            FROM observations o
            JOIN observations_fts f ON o.id = f.rowid
            WHERE observations_fts MATCH ?
        """
        params: list = [fts_query]

        if project:
            sql += " AND o.project = ?"
            params.append(project)
        if obs_type:
            sql += " AND o.type = ?"
            params.append(obs_type)
        if scope:
            sql += " AND o.scope = ?"
            params.append(scope)

        sql += " ORDER BY rank LIMIT ?"
        params.append(limit)

        try:
            rows = conn.execute(sql, params).fetchall()
            results = [_row_to_dict(r) for r in rows]
        except sqlite3.OperationalError as e:
            _log(f"FTS5 search failed, falling back to LIKE: {e}")
            results = _like_search(conn, query, project, obs_type, scope, limit)
    else:
        results = _like_search(conn, query, project, obs_type, scope, limit)

    return {"results": results, "count": len(results)}


def _like_search(conn, query, project, obs_type, scope, limit):
    """Fallback search using LIKE."""
    conditions = []
    params = []
    for token in query.split():
        conditions.append("(title LIKE ? OR content LIKE ? OR topic_key LIKE ?)")
        like = f"%{token}%"
        params.extend([like, like, like])

    sql = "SELECT id, title, SUBSTR(content, 1, 200) as snippet, type, topic_key, scope, project, updated_at FROM observations"
    if conditions:
        sql += " WHERE " + " AND ".join(conditions)

    if project:
        sql += (" AND " if conditions else " WHERE ") + "project = ?"
        params.append(project)
    if obs_type:
        sql += " AND type = ?"
        params.append(obs_type)
    if scope:
        sql += " AND scope = ?"
        params.append(scope)

    sql += " ORDER BY updated_at DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(sql, params).fetchall()
    return [_row_to_dict(r) for r in rows]


def tool_mem_get(conn: sqlite3.Connection, args: dict) -> dict:
    obs_id = args.get("id")
    if obs_id is None:
        return {"error": "id is required"}

    row = conn.execute("SELECT * FROM observations WHERE id = ?", (int(obs_id),)).fetchone()
    if not row:
        return {"error": f"observation {obs_id} not found"}
    return _row_to_dict(row)


def tool_mem_update(conn: sqlite3.Connection, args: dict) -> dict:
    obs_id = args.get("id")
    if obs_id is None:
        return {"error": "id is required"}

    existing = conn.execute("SELECT id FROM observations WHERE id = ?", (int(obs_id),)).fetchone()
    if not existing:
        return {"error": f"observation {obs_id} not found"}

    updates = []
    params = []
    for field in ("title", "content", "type"):
        if field in args and args[field] is not None:
            updates.append(f"{field} = ?")
            params.append(args[field])

    if not updates:
        return {"error": "nothing to update — provide at least one of: title, content, type"}

    updates.append("updated_at = ?")
    params.append(_now())
    params.append(int(obs_id))

    conn.execute(f"UPDATE observations SET {', '.join(updates)} WHERE id = ?", params)
    return {"id": int(obs_id), "action": "updated"}


def tool_mem_context(conn: sqlite3.Connection, args: dict) -> dict:
    project = args.get("project")
    session_id = args.get("session_id")
    limit = int(args.get("limit", 20))

    if not project:
        return {"error": "project is required"}

    sql = """
        SELECT id, title, SUBSTR(content, 1, 200) as snippet, type, topic_key, scope, updated_at
        FROM observations WHERE project = ?
    """
    params: list = [project]

    if session_id:
        sql += " AND session_id = ?"
        params.append(session_id)

    sql += " ORDER BY updated_at DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(sql, params).fetchall()
    return {"results": [_row_to_dict(r) for r in rows], "count": len(rows)}


def tool_mem_session_start(conn: sqlite3.Connection, args: dict) -> dict:
    project = args.get("project")
    goal = args.get("goal")
    session_id = str(uuid.uuid4())
    now = _now()

    conn.execute(
        "INSERT INTO sessions (id, project, goal, started_at) VALUES (?, ?, ?, ?)",
        (session_id, project, goal, now),
    )
    return {"session_id": session_id, "started_at": now}


def tool_mem_session_summary(conn: sqlite3.Connection, args: dict) -> dict:
    session_id = args.get("session_id")
    summary = args.get("summary", "").strip()

    if not session_id:
        return {"error": "session_id is required"}
    if not summary:
        return {"error": "summary is required"}

    now = _now()
    row = conn.execute("SELECT id FROM sessions WHERE id = ?", (session_id,)).fetchone()
    if not row:
        return {"error": f"session {session_id} not found"}

    conn.execute(
        "UPDATE sessions SET summary = ?, ended_at = ? WHERE id = ?",
        (summary, now, session_id),
    )
    return {"session_id": session_id, "ended_at": now, "action": "closed"}


# ---------------------------------------------------------------------------
# Tool registry and schema
# ---------------------------------------------------------------------------

TOOL_HANDLERS = {
    "mem_save": tool_mem_save,
    "mem_search": tool_mem_search,
    "mem_get": tool_mem_get,
    "mem_update": tool_mem_update,
    "mem_context": tool_mem_context,
    "mem_session_start": tool_mem_session_start,
    "mem_session_summary": tool_mem_session_summary,
}

TOOLS_SCHEMA = [
    {
        "name": "mem_save",
        "description": "Save an observation to persistent memory. If topic_key is provided and already exists for the same project, the existing observation is updated (upsert).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Short searchable title (verb + what)"},
                "content": {"type": "string", "description": "Full observation content"},
                "type": {
                    "type": "string",
                    "enum": ["bugfix", "decision", "architecture", "discovery", "pattern", "config", "preference", "convention", "session_summary"],
                    "description": "Observation category",
                },
                "scope": {
                    "type": "string",
                    "enum": ["project", "personal"],
                    "default": "project",
                    "description": "project (default) or personal",
                },
                "topic_key": {"type": "string", "description": "Stable key for upsert (e.g. architecture/auth-model)"},
                "project": {"type": "string", "description": "Project identifier"},
                "session_id": {"type": "string", "description": "Current session UUID"},
            },
            "required": ["title", "content"],
        },
    },
    {
        "name": "mem_search",
        "description": "Full-text search across observations. Uses FTS5 when available, falls back to LIKE.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query text"},
                "project": {"type": "string", "description": "Filter by project"},
                "type": {"type": "string", "description": "Filter by observation type"},
                "scope": {"type": "string", "enum": ["project", "personal"], "description": "Filter by scope"},
                "limit": {"type": "integer", "default": 10, "description": "Max results (default 10)"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "mem_get",
        "description": "Get a full observation by ID without truncation.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Observation ID"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "mem_update",
        "description": "Update an existing observation by ID. Only provided fields are changed.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Observation ID to update"},
                "title": {"type": "string", "description": "New title (optional)"},
                "content": {"type": "string", "description": "New content (optional)"},
                "type": {
                    "type": "string",
                    "enum": ["bugfix", "decision", "architecture", "discovery", "pattern", "config", "preference", "convention", "session_summary"],
                    "description": "New type (optional)",
                },
            },
            "required": ["id"],
        },
    },
    {
        "name": "mem_context",
        "description": "Get recent observations for a project/session, ordered by most recently updated.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project": {"type": "string", "description": "Project identifier"},
                "session_id": {"type": "string", "description": "Filter by session (optional)"},
                "limit": {"type": "integer", "default": 20, "description": "Max results (default 20)"},
            },
            "required": ["project"],
        },
    },
    {
        "name": "mem_session_start",
        "description": "Register a new working session. Returns a UUID session_id.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project": {"type": "string", "description": "Project identifier"},
                "goal": {"type": "string", "description": "Session goal (optional)"},
            },
            "required": ["project"],
        },
    },
    {
        "name": "mem_session_summary",
        "description": "Save a session summary and mark the session as ended.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "session_id": {"type": "string", "description": "Session UUID to close"},
                "summary": {"type": "string", "description": "Session summary content"},
            },
            "required": ["session_id", "summary"],
        },
    },
]


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main():
    # --init flag: create DB/tables and exit (used by installer)
    if "--init" in sys.argv:
        conn = _init_db()
        _migrate_legacy(conn)
        conn.close()
        print(f"OK — database initialized at {DB_PATH} (FTS5: {'yes' if HAS_FTS5 else 'no'})")
        sys.exit(0)

    _log(f"Starting — DB: {DB_PATH}, Project: {PROJECT_DIR}")

    conn = _init_db()
    _log(f"FTS5: {'available' if HAS_FTS5 else 'unavailable (using LIKE fallback)'}")

    _migrate_legacy(conn)

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue

        method = req.get("method")
        rid = req.get("id")

        # Notifications (no id) — just acknowledge
        if method == "notifications/initialized":
            continue

        if method == "initialize":
            _send(_ok(rid, {
                "protocolVersion": "2024-11-05",
                "serverInfo": {"name": "gentleman-memory", "version": "2.0.0"},
                "capabilities": {"tools": {}},
            }))
            continue

        if method == "tools/list":
            _send(_ok(rid, {"tools": TOOLS_SCHEMA}))
            continue

        if method == "tools/call":
            params = req.get("params", {})
            tool_name = params.get("name")
            tool_args = params.get("arguments", {})

            handler = TOOL_HANDLERS.get(tool_name)
            if not handler:
                _send(_text(rid, f"unknown tool: {tool_name}"))
                continue

            try:
                result = handler(conn, tool_args)
                _send(_text(rid, result))
            except Exception as e:
                _log(f"Error in {tool_name}: {e}")
                _send(_error(rid, -32000, f"Tool error: {e}"))
            continue

        # Unknown method
        if rid is not None:
            _send(_error(rid, -32601, f"Method not found: {method}"))


if __name__ == "__main__":
    main()
