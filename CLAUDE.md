# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Claude Gentleman Native — a Claude Code plugin that replicates the Gentleman AI ecosystem using native Claude Code primitives: SDD workflow, specialized sub-agents, coding skills, persistent project memory, security hooks, and a quality gate.

**Not a compiled application.** There is no build step, no package.json, no Node/TS toolchain. The codebase is Markdown (agents, skills), Bash (hooks, scripts), JSON (config), and one Python MCP server.

## Commands

| Command | What it does |
|---------|-------------|
| `make verify-env` | Check that `claude`, `python3`, and `jq` are available |
| `make bootstrap` | Create `.claude/memory/`, `.claude/specs/`, and `AGENTS.md` in the target project |
| `make test-hooks` | Run hook unit tests (`tests/test-hooks.sh`) |
| `make smoke` | Print manual smoke-test checklist |
| `make dev` | Launch Claude Code with this plugin loaded (`claude --plugin-dir .`) |
| `make package` | Bundle plugin into `dist/` via `scripts/package-plugin.sh` |
| `make clean` | Remove `dist/` |

## Architecture

### Plugin Entry Points

- **`.claude-plugin/plugin.json`** — plugin metadata + user config schema. Three user-configurable values: `test_command`, `lint_command`, `docs_glob` (exposed as env vars to MCP server and hooks)
- **`settings.json`** — sets default agent to `gentleman-orchestrator`
- **`.mcp.json`** — declares the `project-memory` MCP server (Python, stdio). `DOCS_GLOB` env var comes from `${user_config.docs_glob}`
- **`hooks/hooks.json`** — registers all event hooks

### Agent Hierarchy

The orchestrator delegates all execution work to specialist agents. It never reads/writes code itself.

```
gentleman-orchestrator (sonnet) — coordinator
  ├── explorer        (haiku)  — read-only codebase investigation
  ├── specifier       (sonnet) — requirements → specs
  ├── designer        (sonnet) — architecture & design docs
  ├── implementer     (sonnet) — code changes (has skills: typescript-strict, react-19, nextjs-15)
  ├── verifier        (haiku)  — QA validation
  ├── code-reviewer   (sonnet) — code quality review
  └── security-reviewer (sonnet) — security audit
```

Agent files live in `agents/*.md` with YAML frontmatter declaring `name`, `model`, `memory`, `skills`, `tools`, and instructions as Markdown body.

### SDD (Spec-Driven Development) Workflow

Nine-phase pipeline, each backed by a skill in `skills/sdd-*`:

```
explore → propose → spec ─┬→ tasks → apply → verify → archive
                           └→ design ┘
```

Skills live in `skills/<name>/SKILL.md` with YAML frontmatter.

### Hooks (Security & Quality)

Defined in `hooks/hooks.json`, scripts in `hooks/`:

| Event | Script | Purpose |
|-------|--------|---------|
| PreToolUse (Edit/Write) | `protect-files.sh` | Block edits to `.env`, `.secrets`, `.pem`, `.key`, `.git/`, `.claude/settings.json` |
| PreToolUse (Bash+git) | `check-git-policy.sh` | Block `git reset --hard`, `git clean -fd`, `git push -f` |
| SessionStart | `memory-inject.sh` | Inject first 200 lines from `.claude/memory/` files into context |
| SessionStart | `memory-snapshot.sh` | Snapshot memory state at session start |
| ConfigChange | `audit-config.sh` | Audit configuration changes to `~/claude-gentleman-config-audit.log` |
| Stop | `stop-verify.sh` + agent prompt | Quality gate — verifies diff, runs lint/tests, checks acceptance criteria before closing |

All hook scripts read JSON from stdin, output JSON to stdout, and use `jq` for parsing. Test fixtures for hooks live in `tests/fixtures/`.

### MCP Server

`servers/project_memory_server.py` — Python stdio JSON-RPC 2.0 server (stdlib only, no external deps). Provides three tools:
- `list_docs` — list project docs matching `DOCS_GLOB` env var (default `**/*.md`), up to 200 files
- `read_memory` — read a specific file from `.claude/memory/`
- `write_memory` — write content to a file in `.claude/memory/`

### Memory

Hybrid strategy:
- **Agent Memory (native)** — declared per-agent via `memory: project` in frontmatter, persists to `~/.claude/agent-memory/`
- **Engram MCP (optional)** — full-text search, session summaries, topic keys for cross-session recovery
- **Project Memory MCP** — the bundled Python server for `.claude/memory/` files

### Templates

`templates/` contains starter files copied during `make bootstrap`:
- `templates/memory/` — conventions, decisions, current-work, questions
- `templates/specs/` — spec, design, tasks
- `templates/rules/AGENTS.md` — team standards template

## Key Conventions

- Hook scripts read JSON from stdin and output JSON to stdout; they use `jq` for manipulation
- All shell scripts are Bash; the only Python is the MCP server
- Agent/skill files use YAML frontmatter for metadata + Markdown body for instructions
- The orchestrator is a coordinator only — it delegates code reading/writing to sub-agents
- The Stop hook acts as a quality gate: tasks cannot close until lint/tests pass and acceptance criteria are met
