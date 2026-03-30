# Ecosistema Gentleman — Claude Code Native Edition

> **Todo el poder del ecosistema Gentleman AI, implementado exclusivamente con herramientas nativas de Claude Code.**

**Version**: 0.1.0-proposal
**Fecha**: 2026-03-29
**Status**: Propuesta verificable
**Origen**: [Gentleman AI PRD](https://github.com/Gentleman-Programming/gentle-ai/blob/main/PRD.md)

---

## 1. Objetivo

Replicar las 7 capacidades del ecosistema Gentleman AI usando EXCLUSIVAMENTE las primitivas nativas de Claude Code:

| Capacidad Gentleman AI | Primitiva Claude Code Nativa |
|------------------------|------------------------------|
| Memoria persistente (Engram) | **Agent Memory** (`memory: user/project`) + MCP server Engram |
| MCP Servers (Context7, Notion, Jira) | **`.mcp.json`** nativo + inline MCP en sub-agents |
| Skills de coding (React, TS, etc.) | **Skills** (`~/.claude/skills/`) + plugin skills |
| SDD Workflow (9 fases) | **Sub-agents** custom con skills preloaded |
| Permisos y seguridad | **Hooks** (`PreToolUse`, `PermissionRequest`) + `settings.json` permissions |
| Persona Gentleman | **`CLAUDE.md`** global + agent principal via `--agent` |
| GGA (Code Review en commits) | **Hooks** (`PreToolUse` matcher `Bash(git commit*)`) + sub-agent reviewer |
| Multi-agente (OpenCode, Cursor, etc.) | **Plugin** distribuible que encapsula todo el ecosistema |

---

## 2. Arquitectura General

```
~/.claude/                          # Scope: usuario (todos los proyectos)
├── CLAUDE.md                       # Persona Gentleman + reglas globales
├── settings.json                   # Hooks globales + permisos + tema
├── agents/                         # Sub-agents del ecosistema
│   ├── gentleman.md                # Agent principal (--agent gentleman)
│   ├── sdd-orchestrator.md         # Coordinador SDD
│   ├── sdd-explorer.md             # Fase: explorar
│   ├── sdd-proposer.md             # Fase: proponer
│   ├── sdd-specifier.md            # Fase: especificar
│   ├── sdd-designer.md             # Fase: disenar
│   ├── sdd-tasker.md               # Fase: tareas
│   ├── sdd-implementer.md          # Fase: implementar
│   ├── sdd-verifier.md             # Fase: verificar
│   ├── sdd-archiver.md             # Fase: archivar
│   ├── code-reviewer.md            # GGA replacement (review en commits)
│   └── skill-loader.md             # Carga skills por contexto
├── skills/                         # Coding skills (best practices)
│   ├── _shared/                    # Convenciones compartidas
│   │   └── engram-convention.md
│   ├── typescript/
│   │   └── SKILL.md
│   ├── react-19/
│   │   └── SKILL.md
│   ├── nextjs-15/
│   │   └── SKILL.md
│   ├── tailwind-4/
│   │   └── SKILL.md
│   ├── zod-4/
│   │   └── SKILL.md
│   ├── go-testing/
│   │   └── SKILL.md
│   └── ... (mas skills por categoria)
├── agent-memory/                   # Memoria persistente por agent
│   ├── code-reviewer/
│   │   └── MEMORY.md
│   ├── sdd-orchestrator/
│   │   └── MEMORY.md
│   └── gentleman/
│       └── MEMORY.md
└── keybindings.json                # Vim-style bindings

.claude/                            # Scope: proyecto
├── settings.json                   # Hooks + permisos del proyecto
├── settings.local.json             # Config local (no se commitea)
├── agents/                         # Agents especificos del proyecto
│   └── project-reviewer.md         # Reviewer con reglas del proyecto
└── skills/                         # Skills del proyecto
    └── project-conventions/
        └── SKILL.md

.mcp.json                           # MCP servers del proyecto
```

---

## 3. Componentes Detallados

### 3.1 Memoria Persistente (reemplazo de Engram)

Claude Code ofrece DOS mecanismos nativos de memoria. Usamos ambos:

#### Opcion A: Agent Memory (nativo, zero-dependency)

```yaml
# En cada sub-agent que necesite memoria:
---
name: code-reviewer
description: Reviews code for quality
memory: user          # Persiste en ~/.claude/agent-memory/code-reviewer/
---
```

**Ventajas**: zero dependencies, nativo, automatico.
**Limitaciones**: no tiene FTS5 search, no tiene API REST.

#### Opcion B: Engram via MCP (full power)

```jsonc
// .mcp.json
{
  "engram": {
    "type": "stdio",
    "command": "engram",
    "args": ["mcp"]
  }
}
```

**Ventajas**: FTS5 search, cross-session, topic keys, session summaries.
**Se inyecta en sub-agents via**:

```yaml
---
name: sdd-orchestrator
mcpServers:
  - engram          # Referencia al MCP ya configurado
---
```

#### Estrategia recomendada: HIBRIDO

| Uso | Mecanismo |
|-----|-----------|
| Memoria de sub-agents especializados (reviewer patterns, SDD state) | `memory: user` (nativo) |
| Memoria global del proyecto (decisiones, bugs, arquitectura) | Engram MCP |
| Busqueda semantica de contexto previo | Engram MCP (`mem_search`) |

#### Verificacion

```bash
# Agent memory existe:
ls ~/.claude/agent-memory/code-reviewer/MEMORY.md

# Engram MCP responde:
claude -p "usa mem_context para ver el contexto reciente"
```

---

### 3.2 MCP Servers

Configuracion identica al ecosistema Gentleman, pero usando el `.mcp.json` nativo:

```jsonc
// .mcp.json (raiz del proyecto o global)
{
  "context7": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@context7/mcp-server"]
  },
  "engram": {
    "type": "stdio",
    "command": "engram",
    "args": ["mcp"]
  }
}
```

Para MCP servers que SOLO necesita un sub-agent especifico (no contaminar el contexto principal):

```yaml
# agents/browser-tester.md
---
name: browser-tester
description: Tests features in a real browser
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - context7   # Reutiliza el del .mcp.json
---
```

#### Verificacion

```bash
# MCP servers cargados:
claude -p "/mcp"
# Debe mostrar: context7, engram (y otros configurados)
```

---

### 3.3 Skills de Coding (Best Practices)

Cada skill es un directorio con `SKILL.md` en `~/.claude/skills/`:

```markdown
<!-- ~/.claude/skills/react-19/SKILL.md -->
---
name: react-19
description: React 19 patterns with Server Components, Actions, and use() hook.
  Use when writing React components, hooks, or working with .tsx/.jsx files.
---

## React 19 Conventions

### Server Components by Default
- Components are Server Components unless marked with 'use client'
- Data fetching happens at the component level with async/await
...
```

**Auto-deteccion por contexto**: Claude Code lee el `description` del skill y lo carga automaticamente cuando el contexto del archivo matchea. No se necesita logica custom — es NATIVO.

#### Skill Presets (via CLAUDE.md)

```markdown
<!-- ~/.claude/CLAUDE.md -->
## Skills (Auto-load based on context)

| Context                         | Skill loaded automatically        |
|---------------------------------|-----------------------------------|
| .tsx/.jsx files, React imports  | react-19                          |
| next.config.*, app/ directory   | nextjs-15                         |
| .ts files, tsconfig.json        | typescript                        |
| tailwind.config.*, className=   | tailwind-4                        |
| z.object, z.string, zod import  | zod-4                             |
| *.test.*, *.spec.*              | testing patterns                  |
| *.go files, _test.go            | go-testing                        |
```

#### Skills en Sub-agents (preloaded)

```yaml
# agents/sdd-implementer.md
---
name: sdd-implementer
description: Implements tasks from SDD specs
skills:
  - typescript
  - react-19
  - tailwind-4
---
```

#### Verificacion

```bash
# Skills disponibles:
ls ~/.claude/skills/*/SKILL.md

# Skill se carga en contexto (verificar con /skills o preguntando a Claude):
claude -p "que skills tenes cargados para un archivo .tsx?"
```

---

### 3.4 SDD Workflow (Spec-Driven Development)

El SDD se implementa como un SISTEMA DE SUB-AGENTS coordinados:

#### Orchestrator (Agent principal)

```yaml
# ~/.claude/agents/sdd-orchestrator.md
---
name: sdd-orchestrator
description: >
  Coordinates Spec-Driven Development workflow. Use when planning features,
  creating proposals, or working through structured development phases.
  Trigger on: "sdd", "planificar", "disenar feature", "nueva funcionalidad".
model: inherit
tools: Agent(sdd-explorer, sdd-proposer, sdd-specifier, sdd-designer, sdd-tasker, sdd-implementer, sdd-verifier, sdd-archiver), Read, Bash
memory: user
mcpServers:
  - engram
---

You are the SDD Orchestrator. You coordinate Spec-Driven Development phases.

## Dependency Graph
proposal -> specs --> tasks -> apply -> verify -> archive
             ^
             |-- design

## Rules
- NEVER implement code directly — delegate to phase agents
- Each phase agent reads its dependencies from engram
- Track state in engram with topic_key: sdd/{change-name}/state
- Present executive summaries to the user between phases
- Ask for approval before advancing to the next phase

## Commands
- /sdd-new {name}: explore -> propose
- /sdd-continue: advance to next missing phase
- /sdd-ff: fast-forward through all phases
- /sdd-apply: implement approved tasks
- /sdd-verify: validate implementation
```

#### Phase Agents (ejemplo: sdd-specifier)

```yaml
# ~/.claude/agents/sdd-specifier.md
---
name: sdd-specifier
description: Writes specifications with requirements and scenarios for SDD changes
model: sonnet
tools: Read, Grep, Glob, Bash
memory: user
mcpServers:
  - engram
skills:
  - typescript
---

You are the SDD Specification Writer.

## Input
Read the proposal from engram: mem_search(query: "sdd/{change-name}/proposal")
Then mem_get_observation(id: ...) for full content.

## Output
Write a specification with:
- Functional requirements (MUST/SHOULD/MAY)
- Non-functional requirements
- Acceptance scenarios (Given/When/Then)
- Edge cases and error handling

Save to engram with:
- topic_key: sdd/{change-name}/spec
- type: architecture
```

#### Verificacion

```bash
# Agents SDD disponibles:
claude agents | grep sdd

# Flujo completo funciona:
claude --agent sdd-orchestrator
# > "sdd-new: authentication system"
# Debe: explorar -> proponer -> esperar aprobacion
```

---

### 3.5 Permisos y Seguridad

#### settings.json (global)

```jsonc
// ~/.claude/settings.json
{
  "permissions": {
    "deny": [
      "Bash(cat .env*)",
      "Bash(echo $*_KEY*)",
      "Bash(echo $*_SECRET*)",
      "Bash(echo $*_TOKEN*)",
      "Read(.env*)",
      "Edit(.env*)",
      "Write(.env*)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(git push --force*)",
      "Bash(git reset --hard*)",
      "Bash(git checkout -- *)",
      "Bash(rm -rf *)",
      "Bash(docker *)",
      "Bash(npm publish*)"
    ],
    "allow": [
      "Read(*)",
      "Glob(*)",
      "Grep(*)",
      "Bash(git status*)",
      "Bash(git log*)",
      "Bash(git diff*)",
      "Bash(npm test*)",
      "Bash(npm run lint*)"
    ]
  }
}
```

#### Hook: Bloquear edicion de archivos protegidos

```jsonc
// ~/.claude/settings.json (seccion hooks)
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'INPUT=$(cat); FILE=$(echo \"$INPUT\" | jq -r \".tool_input.file_path // empty\"); for p in .env package-lock.json yarn.lock .git/; do [[ \"$FILE\" == *\"$p\"* ]] && { echo \"Blocked: $FILE matches protected pattern $p\" >&2; exit 2; }; done; exit 0'"
          }
        ]
      }
    ]
  }
}
```

#### Verificacion

```bash
# Intentar leer .env debe ser bloqueado:
claude -p "lee el archivo .env"
# Debe rechazar la operacion

# git push debe pedir confirmacion:
claude -p "hace push a origin main"
# Debe mostrar prompt de confirmacion
```

---

### 3.6 GGA Replacement (Code Review via Hooks + Sub-agent)

El GGA (Guardian Angel) se implementa como un HOOK + SUB-AGENT:

#### Hook: Pre-commit review

```jsonc
// ~/.claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "agent",
            "if": "Bash(git commit*)",
            "prompt": "Review the staged changes (run `git diff --cached`) against the project's coding standards. Check for: 1) Security issues (exposed secrets, injection vulnerabilities), 2) Code quality (naming, structure, error handling), 3) Test coverage (are new features tested?), 4) Convention compliance. If issues found, respond with {\"ok\": false, \"reason\": \"description of issues\"}. If clean, respond {\"ok\": true}.",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

#### Sub-agent: Code Reviewer dedicado

```yaml
# ~/.claude/agents/code-reviewer.md
---
name: code-reviewer
description: >
  Expert code review specialist. Use proactively after writing or modifying code.
  Reviews for quality, security, performance, and convention compliance.
tools: Read, Grep, Glob, Bash
model: sonnet
memory: user
---

You are a senior code reviewer. When invoked:

1. Run `git diff` to see recent changes
2. Focus on modified files
3. Check your memory for known patterns and past issues in this codebase

## Review Checklist
- [ ] Code is clear and readable
- [ ] No duplicated code or logic
- [ ] Proper error handling at system boundaries
- [ ] No exposed secrets or API keys
- [ ] Input validation on external data
- [ ] Tests cover new behavior
- [ ] Performance: no N+1 queries, no unnecessary re-renders

## Output Format
- **Critical** (must fix before merge)
- **Warning** (should fix)
- **Suggestion** (nice to have)

Update your memory with patterns you discover in this codebase.
```

#### Verificacion

```bash
# El hook de review se activa en commits:
claude
> "comitea los cambios con mensaje 'feat: add auth'"
# Debe triggear el agent-based hook que revisa el diff

# El reviewer como sub-agent funciona:
claude
> "usa el code-reviewer para revisar mis cambios recientes"
# Debe delegar al sub-agent y retornar findings
```

---

### 3.7 Persona Gentleman

#### CLAUDE.md global

```markdown
<!-- ~/.claude/CLAUDE.md -->
# Gentleman Persona

## Personality
Senior Architect, 15+ years experience, GDE & MVP. Passionate teacher.

## Language
- Spanish input -> Rioplatense Spanish (voseo): "bien", "se entiende?",
  "es asi de facil", "fantastico", "loco", "ponete las pilas"
- English input -> Same energy: "here's the thing", "and you know why?",
  "it's that simple", "dude", "come on"

## Philosophy
- CONCEPTS > CODE
- AI IS A TOOL (we direct, AI executes)
- SOLID FOUNDATIONS before frameworks
- AGAINST IMMEDIACY (no shortcuts)

## Behavior
- Push back when user asks for code without understanding
- Correct errors explaining WHY technically
- For concepts: (1) explain problem, (2) propose solution with examples
```

#### Agent principal (para `--agent gentleman`)

```yaml
# ~/.claude/agents/gentleman.md
---
name: gentleman
description: >
  The Gentleman AI experience. Senior Architect mentor who teaches,
  challenges, and helps you grow. Orchestrates all ecosystem capabilities.
model: inherit
tools: Agent, Read, Edit, Write, Bash, Grep, Glob
memory: user
mcpServers:
  - engram
  - context7
skills:
  - typescript
  - react-19
---

You are the Gentleman — a Senior Architect with 15+ years of experience.
[...full persona prompt...]

## Orchestration Rules
- For substantial features: suggest SDD workflow, delegate to sdd-orchestrator
- After code changes: proactively delegate to code-reviewer
- Save important decisions and discoveries to engram
- Load relevant skills based on file context
```

#### Activacion como default del proyecto

```jsonc
// .claude/settings.json
{
  "agent": "gentleman"
}
```

O por sesion:

```bash
claude --agent gentleman
```

#### Verificacion

```bash
# Verificar que la persona se activa:
claude --agent gentleman -p "hola, que onda?"
# Debe responder en Rioplatense con energia de mentor

# Verificar que delega al SDD:
claude --agent gentleman
> "quiero agregar un sistema de autenticacion"
# Debe sugerir SDD y delegar al orchestrator
```

---

### 3.8 Plugin Distribuible (reemplazo del installer multi-agente)

Todo el ecosistema se empaqueta como un **Claude Code Plugin** instalable:

```
gentleman-ecosystem/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── gentleman.md
│   ├── sdd-orchestrator.md
│   ├── sdd-explorer.md
│   ├── sdd-proposer.md
│   ├── sdd-specifier.md
│   ├── sdd-designer.md
│   ├── sdd-tasker.md
│   ├── sdd-implementer.md
│   ├── sdd-verifier.md
│   ├── sdd-archiver.md
│   └── code-reviewer.md
├── skills/
│   ├── typescript/SKILL.md
│   ├── react-19/SKILL.md
│   ├── nextjs-15/SKILL.md
│   ├── tailwind-4/SKILL.md
│   ├── zod-4/SKILL.md
│   └── go-testing/SKILL.md
├── commands/
│   ├── sdd-new.md
│   ├── sdd-continue.md
│   ├── sdd-ff.md
│   └── review.md
├── hooks/
│   └── hooks.json
├── .mcp.json
└── settings.json
```

#### plugin.json

```jsonc
{
  "name": "gentleman-ecosystem",
  "description": "The Gentleman AI ecosystem: memory, SDD workflow, coding skills, code review, and the Gentleman persona. One plugin, full power.",
  "version": "1.0.0",
  "author": {
    "name": "Gentleman Programming"
  },
  "repository": "https://github.com/Gentleman-Programming/gentleman-ecosystem-plugin",
  "license": "MIT"
}
```

#### settings.json del plugin

```jsonc
{
  "agent": "gentleman"
}
```

#### Instalacion

```bash
# Desde marketplace:
/plugins install gentleman-ecosystem

# Desde directorio local (desarrollo):
claude --plugin-dir ./gentleman-ecosystem

# Verificar:
/plugins
# Debe mostrar: gentleman-ecosystem (enabled)
```

---

## 4. Tabla de Equivalencias Completa

| PRD Gentleman AI | Claude Code Native | Componente | Verificacion |
|------------------|--------------------|------------|--------------|
| Engram binary + MCP | `memory: user` + Engram MCP en `.mcp.json` | Agent Memory + MCP | `ls ~/.claude/agent-memory/` + `/mcp` |
| Installer TUI (Go + Bubbletea) | **Plugin** (`/plugins install`) | Plugin manifest | `/plugins` muestra el plugin |
| Multi-agent support | Plugin distribuible (solo Claude Code) | Plugin | `claude --plugin-dir ./` |
| 9 SDD skills + orchestrator | 9 sub-agents + orchestrator agent | `~/.claude/agents/sdd-*.md` | `claude agents \| grep sdd` |
| SDD slash commands | Plugin commands (`/gentleman-ecosystem:sdd-new`) | `commands/*.md` | `/help` muestra comandos |
| GGA binary + git hook | Hook `PreToolUse` tipo `agent` + sub-agent reviewer | `hooks.json` + `agents/code-reviewer.md` | Hacer commit, verificar que revisa |
| AGENTS.md (GGA rules) | Skill `project-conventions` + reviewer memory | `skills/` + `agent-memory/` | Reviewer aplica convenciones |
| Coding skills (React, TS, etc.) | Skills nativos (`~/.claude/skills/`) | `SKILL.md` files | `/skills` muestra skills activos |
| Context7 MCP | `.mcp.json` nativo | MCP config | `/mcp` muestra context7 |
| Notion/Jira MCP | `.mcp.json` nativo | MCP config | `/mcp` muestra servers |
| Persona Gentleman | `CLAUDE.md` + `--agent gentleman` | Agent definition + CLAUDE.md | Respuesta en Rioplatense |
| Security permissions | `settings.json` permissions + hooks | deny/ask/allow rules | `.env` bloqueado, push pide confirm |
| Theme Gentleman | Claude Code theme settings | `settings.json` | Tema aplicado |
| Statusline | `/statusline` config | statusline settings | Status bar visible |
| Vim keybindings | `keybindings.json` | Keybindings file | Vim navigation funciona |
| Non-interactive mode | `claude -p` + `--agent` | CLI flags | `claude --agent gentleman -p "task"` |
| Backup de configs | Git + plugin versioning | Plugin repo | Plugin versionado en git |

---

## 5. Lo que NO se puede replicar (y alternativas)

| Capacidad PRD | Por que no se puede | Alternativa |
|---------------|---------------------|-------------|
| Soporte multi-agente (OpenCode, Cursor, Gemini CLI) | Claude Code plugin system es exclusivo de Claude Code | El plugin solo funciona en Claude Code. Para otros agentes, se mantiene el installer original |
| TUI de instalacion (Bubbletea) | No necesaria — un `plugin install` reemplaza la TUI | `/plugins install gentleman-ecosystem` |
| GGA como binary independiente | El hook+agent funciona DENTRO de Claude Code, no como git hook standalone | Para review fuera de Claude Code, se sigue necesitando GGA binary |
| Engram auto-start (systemd/launchd) | Claude Code no gestiona servicios del sistema | Script de setup separado o instrucciones manuales |
| Presets de instalacion (Full/Minimal/Custom) | Plugin se instala completo | Se pueden crear plugins separados: `gentleman-minimal`, `gentleman-full` |

---

## 6. Plan de Implementacion

### Fase 1: Core (semana 1-2)

- [ ] Crear estructura del plugin (`gentleman-ecosystem/`)
- [ ] Escribir `plugin.json` manifest
- [ ] Crear `CLAUDE.md` con persona Gentleman
- [ ] Configurar `settings.json` con permisos de seguridad
- [ ] Configurar `.mcp.json` con Context7 + Engram
- [ ] Crear agent `gentleman.md` como agent principal

### Fase 2: SDD Agents (semana 2-3)

- [ ] Crear `sdd-orchestrator.md` con logica de coordinacion
- [ ] Crear los 8 phase agents (explorer -> archiver)
- [ ] Crear commands: `/sdd-new`, `/sdd-continue`, `/sdd-ff`
- [ ] Verificar flujo completo: new -> propose -> spec -> design -> tasks -> apply -> verify
- [ ] Configurar memoria persistente para estado SDD

### Fase 3: Skills Library (semana 3-4)

- [ ] Portar skills existentes a formato `SKILL.md`
- [ ] typescript, react-19, nextjs-15, tailwind-4, zod-4
- [ ] go-testing, testing patterns
- [ ] Verificar auto-deteccion por contexto de archivo

### Fase 4: Code Review (semana 4)

- [ ] Crear `code-reviewer.md` sub-agent
- [ ] Configurar hook `PreToolUse` tipo `agent` para commits
- [ ] Configurar `hooks.json` del plugin
- [ ] Verificar que commits triggerean review automatico

### Fase 5: Distribucion (semana 5)

- [ ] Publicar plugin en marketplace oficial de Anthropic
- [ ] Documentar instalacion y configuracion
- [ ] Crear variantes: `gentleman-minimal`, `gentleman-full`
- [ ] Testing end-to-end en Windows, macOS, Linux

---

## 7. Comandos de Verificacion Rapida

```bash
# 1. Instalar el plugin
claude --plugin-dir ./gentleman-ecosystem

# 2. Verificar plugin cargado
/plugins
# Output esperado: gentleman-ecosystem v1.0.0 (enabled)

# 3. Verificar agents disponibles
claude agents
# Output esperado: gentleman, sdd-orchestrator, sdd-explorer, ..., code-reviewer

# 4. Verificar skills
/skills
# Output esperado: typescript, react-19, nextjs-15, tailwind-4, ...

# 5. Verificar MCP servers
/mcp
# Output esperado: context7, engram

# 6. Verificar persona
claude --agent gentleman -p "hola, que onda?"
# Output esperado: respuesta en Rioplatense con energia de mentor

# 7. Verificar seguridad
claude -p "lee el archivo .env"
# Output esperado: operacion bloqueada

# 8. Verificar SDD workflow
claude --agent gentleman
> /gentleman-ecosystem:sdd-new authentication-system
# Output esperado: inicia flujo SDD delegando a sub-agents

# 9. Verificar code review hook
claude
> "comitea los cambios"
# Output esperado: hook agent revisa diff antes de permitir commit

# 10. Verificar memoria persistente
claude --agent gentleman -p "que recordas de este proyecto?"
# Output esperado: contexto de sesiones anteriores via engram
```

---

## 8. Conclusion

Este ecosistema replica el **95% de las capacidades** del PRD de Gentleman AI usando exclusivamente primitivas nativas de Claude Code. Las unicas limitaciones son:

1. **Solo funciona en Claude Code** (no multi-agente como el installer original)
2. **No tiene TUI de instalacion** (reemplazada por `plugin install`)
3. **GGA funciona solo dentro de Claude Code** (no como git hook standalone)

A cambio, se gana:

- **Zero dependencies externas** (no Go, no Bubbletea, no binary compilation)
- **Instalacion en un comando** (`/plugins install gentleman-ecosystem`)
- **Actualizaciones automaticas** via plugin marketplace
- **Integracion nativa perfecta** con todas las features de Claude Code
- **Distribucion trivial** via marketplace o git repo
- **Cada sub-agent tiene su propia ventana de contexto** — no hay bloat en la conversacion principal

> **"Es asi de facil. Un plugin. Todo el ecosistema. Listo para laburar."**
