#!/usr/bin/env python3
"""
Gentleman Memory MCP Server — SQLite+FTS5 persistent memory for Claude Code.
Drop-in replacement for Engram. Exposes the same tool names and parameters.

JSON-RPC 2.0 over stdio. Provides 12 tools: mem_save, mem_search,
mem_get_observation, mem_update, mem_context, mem_session_start,
mem_session_end, mem_session_summary, mem_save_prompt,
mem_capture_passive, mem_suggest_topic_key.

Database: ~/.claude/gentleman-memory/memory.db (WAL mode, FTS5 full-text search).
Auto-migrates from legacy .claude/memory/*.md files on first run.
Python 3 stdlib only — no external dependencies.
"""

import json
import os
import re
import sqlite3
import sys
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

VALID_TYPES = frozenset({
    "tool_use", "file_change", "command", "file_read", "search", "manual",
    "decision", "architecture", "bugfix", "pattern", "config", "discovery",
    "learning", "preference", "convention", "session_summary", "prompt",
})

VALID_SCOPES = frozenset({"project", "personal"})

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

    # Check if observations table exists and has the old CHECK constraint
    _migrate_check_constraint(conn)

    # Core tables — no CHECK constraint on type (validated in Python)
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS observations (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT NOT NULL,
            content     TEXT NOT NULL,
            type        TEXT,
            scope       TEXT DEFAULT 'project',
            topic_key   TEXT,
            project     TEXT,
            session_id  TEXT,
            created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id          TEXT PRIMARY KEY,
            project     TEXT,
            directory   TEXT,
            goal        TEXT,
            summary     TEXT,
            started_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
            ended_at    DATETIME
        );
    """)

    # Add directory column to sessions if missing (migration)
    try:
        conn.execute("ALTER TABLE sessions ADD COLUMN directory TEXT")
    except sqlite3.OperationalError:
        pass  # already exists

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


def _migrate_check_constraint(conn: sqlite3.Connection) -> None:
    """If the old observations table has a CHECK constraint on type, recreate without it."""
    row = conn.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='observations'"
    ).fetchone()
    if row is None:
        return  # table doesn't exist yet, will be created fresh

    create_sql = row[0] or ""
    if "CHECK" not in create_sql.upper():
        return  # no CHECK constraint, nothing to migrate

    _log("Migrating observations table to remove CHECK constraint on type...")
    conn.executescript("""
        ALTER TABLE observations RENAME TO _observations_old;

        CREATE TABLE observations (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT NOT NULL,
            content     TEXT NOT NULL,
            type        TEXT,
            scope       TEXT DEFAULT 'project',
            topic_key   TEXT,
            project     TEXT,
            session_id  TEXT,
            created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        INSERT INTO observations SELECT * FROM _observations_old;
        DROP TABLE _observations_old;
    """)

    # Rebuild FTS index if it exists
    try:
        conn.execute("INSERT INTO observations_fts(observations_fts) VALUES('rebuild')")
    except sqlite3.OperationalError:
        pass

    _log("Migration complete — CHECK constraint removed.")


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


def _validate_type(obs_type: str | None) -> str | None:
    """Validate observation type. Returns the type or None if invalid/empty."""
    if obs_type is None or obs_type == "":
        return None
    if obs_type not in VALID_TYPES:
        _log(f"Warning: unrecognized type '{obs_type}', allowing anyway")
    return obs_type


def _normalize_topic_key(raw: str) -> str:
    """Lowercase, replace spaces with hyphens, strip special chars."""
    key = raw.lower().strip()
    key = re.sub(r"[^a-z0-9/_-]", "", key.replace(" ", "-"))
    key = re.sub(r"-+", "-", key).strip("-")
    return key


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

def tool_mem_save(conn: sqlite3.Connection, args: dict) -> dict:
    title = args.get("title", "").strip()
    content = args.get("content", "").strip()
    obs_type = _validate_type(args.get("type"))
    scope = args.get("scope", "project")
    topic_key = args.get("topic_key")
    project = args.get("project")
    session_id = args.get("session_id")

    if not title or not content:
        return {"error": "title and content are required"}

    if topic_key:
        topic_key = _normalize_topic_key(topic_key)

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
    limit = min(int(args.get("limit", 10)), 20)

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


def tool_mem_get_observation(conn: sqlite3.Connection, args: dict) -> dict:
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
    for field in ("title", "content", "type", "topic_key", "scope", "project"):
        if field in args and args[field] is not None:
            value = args[field]
            if field == "topic_key":
                value = _normalize_topic_key(value)
            if field == "type":
                value = _validate_type(value) or value
            updates.append(f"{field} = ?")
            params.append(value)

    if not updates:
        return {"error": "nothing to update — provide at least one of: title, content, type, topic_key, scope, project"}

    updates.append("updated_at = ?")
    params.append(_now())
    params.append(int(obs_id))

    conn.execute(f"UPDATE observations SET {', '.join(updates)} WHERE id = ?", params)
    return {"id": int(obs_id), "action": "updated"}


def tool_mem_context(conn: sqlite3.Connection, args: dict) -> dict:
    project = args.get("project")
    scope = args.get("scope")
    limit = int(args.get("limit", 20))

    sql = "SELECT id, title, SUBSTR(content, 1, 200) as snippet, type, topic_key, scope, updated_at FROM observations"
    conditions = []
    params: list = []

    if project:
        conditions.append("project = ?")
        params.append(project)
    if scope:
        conditions.append("scope = ?")
        params.append(scope)

    if conditions:
        sql += " WHERE " + " AND ".join(conditions)

    sql += " ORDER BY updated_at DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(sql, params).fetchall()
    return {"results": [_row_to_dict(r) for r in rows], "count": len(rows)}


def tool_mem_session_start(conn: sqlite3.Connection, args: dict) -> dict:
    session_id = args.get("id")
    project = args.get("project")
    directory = args.get("directory")

    if not session_id:
        return {"error": "id is required"}
    if not project:
        return {"error": "project is required"}

    now = _now()
    conn.execute(
        "INSERT INTO sessions (id, project, directory, started_at) VALUES (?, ?, ?, ?)",
        (session_id, project, directory, now),
    )
    return {"session_id": session_id, "started_at": now}


def tool_mem_session_end(conn: sqlite3.Connection, args: dict) -> dict:
    session_id = args.get("id")
    summary = args.get("summary")

    if not session_id:
        return {"error": "id is required"}

    row = conn.execute("SELECT id FROM sessions WHERE id = ?", (session_id,)).fetchone()
    if not row:
        return {"error": f"session {session_id} not found"}

    now = _now()
    if summary:
        conn.execute(
            "UPDATE sessions SET summary = ?, ended_at = ? WHERE id = ?",
            (summary, now, session_id),
        )
    else:
        conn.execute(
            "UPDATE sessions SET ended_at = ? WHERE id = ?",
            (now, session_id),
        )
    return {"session_id": session_id, "ended_at": now, "action": "closed"}


def tool_mem_session_summary(conn: sqlite3.Connection, args: dict) -> dict:
    content = args.get("content", "").strip()
    project = args.get("project")
    session_id = args.get("session_id")

    if not content:
        return {"error": "content is required"}
    if not project:
        return {"error": "project is required"}

    # Default session_id if not provided
    if not session_id:
        session_id = f"manual-save-{project}"

    now = _now()

    # Save as a session_summary observation
    cur = conn.execute(
        """INSERT INTO observations (title, content, type, scope, topic_key, project, session_id, created_at, updated_at)
           VALUES (?, ?, 'session_summary', 'project', ?, ?, ?, ?, ?)""",
        ("Session summary", content, f"session-summary/{session_id}", project, session_id, now, now),
    )

    # Also update the session record if it exists
    existing_session = conn.execute("SELECT id FROM sessions WHERE id = ?", (session_id,)).fetchone()
    if existing_session:
        conn.execute(
            "UPDATE sessions SET summary = ?, ended_at = ? WHERE id = ?",
            (content, now, session_id),
        )

    return {"id": cur.lastrowid, "session_id": session_id, "action": "saved"}


def tool_mem_save_prompt(conn: sqlite3.Connection, args: dict) -> dict:
    content = args.get("content", "").strip()
    project = args.get("project")
    session_id = args.get("session_id")

    if not content:
        return {"error": "content is required"}

    if not session_id and project:
        session_id = f"manual-save-{project}"

    now = _now()
    cur = conn.execute(
        """INSERT INTO observations (title, content, type, scope, project, session_id, created_at, updated_at)
           VALUES (?, ?, 'prompt', 'project', ?, ?, ?, ?)""",
        ("User prompt", content, project, session_id, now, now),
    )
    return {"id": cur.lastrowid, "action": "created"}


def tool_mem_capture_passive(conn: sqlite3.Connection, args: dict) -> dict:
    content = args.get("content", "").strip()
    project = args.get("project")
    session_id = args.get("session_id")
    source = args.get("source")

    if not content:
        return {"error": "content is required"}

    if not session_id and project:
        session_id = f"manual-save-{project}"

    now = _now()

    # Look for "## Key Learnings:" or "## Aprendizajes Clave:" sections
    learnings_pattern = re.compile(
        r"##\s*(?:Key Learnings|Aprendizajes Clave)\s*:?\s*\n(.*?)(?=\n##|\Z)",
        re.DOTALL | re.IGNORECASE,
    )
    match = learnings_pattern.search(content)

    saved = []
    skipped = []

    if match:
        section = match.group(1)
        # Extract numbered (1. ...) or bulleted (- ..., * ...) items
        items = re.findall(r"(?:^|\n)\s*(?:\d+[.)]\s*|[-*]\s+)(.+)", section)
        if not items:
            items = [section.strip()]

        for item in items:
            item = item.strip()
            if not item:
                continue

            title = item[:100] if len(item) > 100 else item

            # Deduplicate: check if same title+project already exists
            existing = conn.execute(
                "SELECT id FROM observations WHERE title = ? AND project = ? AND type = 'learning'",
                (title, project),
            ).fetchone()
            if existing:
                skipped.append(title)
                continue

            cur = conn.execute(
                """INSERT INTO observations (title, content, type, scope, project, session_id, created_at, updated_at)
                   VALUES (?, ?, 'learning', 'project', ?, ?, ?, ?)""",
                (title, item, project, session_id, now, now),
            )
            saved.append({"id": cur.lastrowid, "title": title})
    else:
        # No learnings section found — save the whole content as a single observation
        title = content[:100] if len(content) > 100 else content
        title_oneline = title.split("\n")[0]

        existing = conn.execute(
            "SELECT id FROM observations WHERE title = ? AND project = ? AND type = 'learning'",
            (title_oneline, project),
        ).fetchone()
        if existing:
            skipped.append(title_oneline)
        else:
            cur = conn.execute(
                """INSERT INTO observations (title, content, type, scope, project, session_id, created_at, updated_at)
                   VALUES (?, ?, 'learning', 'project', ?, ?, ?, ?)""",
                (title_oneline, content, project, session_id, now, now),
            )
            saved.append({"id": cur.lastrowid, "title": title_oneline})

    return {
        "saved": saved,
        "skipped": skipped,
        "source": source,
        "count_saved": len(saved),
        "count_skipped": len(skipped),
    }


def tool_mem_suggest_topic_key(conn: sqlite3.Connection, args: dict) -> dict:
    title = args.get("title", "").strip()
    content = args.get("content", "").strip()
    obs_type = args.get("type", "").strip()

    # Take title (preferred) or first 50 chars of content
    base = title if title else content[:50]
    if not base:
        return {"topic_key": "misc/untitled"}

    # Normalize: lowercase, replace spaces with hyphens, remove special chars
    key = base.lower().strip()
    key = key.replace(" ", "-")
    key = re.sub(r"[^a-z0-9/_-]", "", key)
    key = re.sub(r"-+", "-", key).strip("-")

    # Truncate to reasonable length
    if len(key) > 60:
        key = key[:60].rstrip("-")

    # Prepend type/ if type is provided
    if obs_type:
        obs_type_normalized = obs_type.lower().strip()
        # Don't double-prefix if key already starts with the type
        if not key.startswith(f"{obs_type_normalized}/"):
            key = f"{obs_type_normalized}/{key}"

    return {"topic_key": key}


# ---------------------------------------------------------------------------
# Tool registry and schema
# ---------------------------------------------------------------------------

TOOL_HANDLERS = {
    "mem_save": tool_mem_save,
    "mem_search": tool_mem_search,
    "mem_get_observation": tool_mem_get_observation,
    "mem_update": tool_mem_update,
    "mem_context": tool_mem_context,
    "mem_session_start": tool_mem_session_start,
    "mem_session_end": tool_mem_session_end,
    "mem_session_summary": tool_mem_session_summary,
    "mem_save_prompt": tool_mem_save_prompt,
    "mem_capture_passive": tool_mem_capture_passive,
    "mem_suggest_topic_key": tool_mem_suggest_topic_key,
}

TOOLS_SCHEMA = [
    {
        "name": "mem_save",
        "description": (
            "Save an important observation to persistent memory. Call this PROACTIVELY after completing significant work — don't wait to be asked.\n\n"
            "WHEN to save (call this after each of these):\n"
            "- Architectural decisions or tradeoffs\n"
            "- Bug fixes (what was wrong, why, how you fixed it)\n"
            "- New patterns or conventions established\n"
            "- Configuration changes or environment setup\n"
            "- Important discoveries or gotchas\n"
            "- File structure changes\n\n"
            "FORMAT for content — use this structured format:\n"
            "  **What**: [concise description of what was done]\n"
            "  **Why**: [the reasoning, user request, or problem that drove it]\n"
            "  **Where**: [files/paths affected]\n"
            "  **Learned**: [any gotchas, edge cases, or decisions made — omit if none]\n\n"
            "TITLE should be short and searchable. If topic_key is provided and already exists for the same project, the existing observation is updated (upsert)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Short, searchable title (e.g. 'JWT auth middleware', 'Fixed N+1 query')"},
                "content": {"type": "string", "description": "Structured content using **What**, **Why**, **Where**, **Learned** format"},
                "type": {
                    "type": "string",
                    "description": "Category: decision, architecture, bugfix, pattern, config, discovery, learning (default: manual)",
                },
                "scope": {
                    "type": "string",
                    "description": "Scope for this observation: project (default) or personal",
                },
                "topic_key": {"type": "string", "description": "Optional topic identifier for upserts (e.g. architecture/auth-model). Reuses and updates the latest observation in same project+scope."},
                "project": {"type": "string", "description": "Project name"},
                "session_id": {"type": "string", "description": "Session ID to associate with (default: manual-save-{project})"},
            },
            "required": ["title", "content"],
        },
    },
    {
        "name": "mem_search",
        "description": "Search your persistent memory across all sessions. Uses FTS5 when available, falls back to LIKE. Use this to find past decisions, bugs fixed, patterns used, files changed, or any context from previous coding sessions.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query — natural language or keywords"},
                "project": {"type": "string", "description": "Filter by project name"},
                "type": {"type": "string", "description": "Filter by type: tool_use, file_change, command, file_read, search, manual, decision, architecture, bugfix, pattern"},
                "scope": {"type": "string", "description": "Filter by scope: project (default) or personal"},
                "limit": {"type": "number", "default": 10, "description": "Max results (default: 10, max: 20)"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "mem_get_observation",
        "description": "Get the full content of a specific observation by ID. Use when you need the complete, untruncated content of an observation found via mem_search or mem_timeline.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "number", "description": "The observation ID to retrieve"},
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
                "id": {"type": "number", "description": "Observation ID to update"},
                "title": {"type": "string", "description": "New title"},
                "content": {"type": "string", "description": "New content"},
                "type": {"type": "string", "description": "New type/category"},
                "topic_key": {"type": "string", "description": "New topic key (normalized internally)"},
                "scope": {"type": "string", "description": "New scope: project or personal"},
                "project": {"type": "string", "description": "New project value"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "mem_context",
        "description": "Get recent memory context from previous sessions. Shows recent sessions and observations to understand what was done before.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project": {"type": "string", "description": "Filter by project (omit for all projects)"},
                "scope": {"type": "string", "description": "Filter observations by scope: project (default) or personal"},
                "limit": {"type": "number", "default": 20, "description": "Number of observations to retrieve (default: 20)"},
            },
            "required": [],
        },
    },
    {
        "name": "mem_session_start",
        "description": "Register the start of a new coding session. Call this at the beginning of a session to track activity.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "string", "description": "Unique session identifier"},
                "project": {"type": "string", "description": "Project name"},
                "directory": {"type": "string", "description": "Working directory"},
            },
            "required": ["id", "project"],
        },
    },
    {
        "name": "mem_session_end",
        "description": "Mark a coding session as completed with an optional summary.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "string", "description": "Session identifier to close"},
                "summary": {"type": "string", "description": "Summary of what was accomplished"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "mem_session_summary",
        "description": (
            "Save a comprehensive end-of-session summary. Call this when a session is ending or when significant work is complete. "
            "This creates a structured summary that future sessions will use to understand what happened.\n\n"
            "FORMAT — use this exact structure in the content field:\n\n"
            "## Goal\n[One sentence: what were we building/working on in this session]\n\n"
            "## Instructions\n[User preferences, constraints, or context discovered during this session.]\n\n"
            "## Discoveries\n- [Technical finding, gotcha, or learning 1]\n\n"
            "## Accomplished\n- [Completed task 1 — with key implementation details]\n\n"
            "## Relevant Files\n- path/to/file.ts — [what it does or what changed]"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "Full session summary using the Goal/Instructions/Discoveries/Accomplished/Files format"},
                "project": {"type": "string", "description": "Project name"},
                "session_id": {"type": "string", "description": "Session ID (default: manual-save-{project})"},
            },
            "required": ["content", "project"],
        },
    },
    {
        "name": "mem_save_prompt",
        "description": "Save a user prompt to persistent memory. Use this to record what the user asked — their intent, questions, and requests — so future sessions have context about the user's goals.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "The user's prompt text"},
                "project": {"type": "string", "description": "Project name"},
                "session_id": {"type": "string", "description": "Session ID to associate with (default: manual-save-{project})"},
            },
            "required": ["content"],
        },
    },
    {
        "name": "mem_capture_passive",
        "description": (
            "Extract and save structured learnings from text output. Use this at the end of a task to capture knowledge automatically.\n\n"
            "The tool looks for sections like \"## Key Learnings:\" or \"## Aprendizajes Clave:\" and extracts numbered or bulleted items. "
            "Each item is saved as a separate observation.\n\n"
            "Duplicates are automatically detected and skipped — safe to call multiple times with the same content."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "The text output containing a '## Key Learnings:' section with numbered or bulleted items"},
                "project": {"type": "string", "description": "Project name"},
                "session_id": {"type": "string", "description": "Session ID (default: manual-save-{project})"},
                "source": {"type": "string", "description": "Source identifier (e.g. 'subagent-stop', 'session-end')"},
            },
            "required": ["content"],
        },
    },
    {
        "name": "mem_suggest_topic_key",
        "description": "Suggest a stable topic_key for memory upserts. Use this before mem_save when you want evolving topics (like architecture decisions) to update a single observation over time.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Observation title (preferred input for stable keys)"},
                "content": {"type": "string", "description": "Observation content used as fallback if title is empty"},
                "type": {"type": "string", "description": "Observation type/category, e.g. architecture, decision, bugfix"},
            },
            "required": [],
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
                "serverInfo": {"name": "gentleman-memory", "version": "3.0.0"},
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
