# Ecosistema Claude — Gentleman Native

> Tu equipo de desarrollo AI con metodologia, memoria y seguridad. Un plugin, un comando, todo funcionando.

## Que es esto

Gentleman Native es un plugin para [Claude Code](https://docs.anthropic.com/en/docs/claude-code) que te arma un **equipo completo de desarrollo AI** adentro de tu terminal. En vez de un solo Claude que hace todo, tenes un orquestador que delega a agentes especializados: uno explora, otro especifica, otro implementa, otro revisa seguridad, otro hace QA. Cada uno con su modelo, sus herramientas y sus restricciones.

El plugin trae un flujo de trabajo llamado **SDD (Spec-Driven Development)** para cambios sustanciales: antes de tocar codigo, se explora, se especifica, se diseña y se planifican las tareas. Recien ahi se implementa, se verifica y se archiva. Para cambios chicos, el orquestador delega directo sin todo el pipeline.

Ademas incluye **memoria persistente** (SQLite + FTS5 via Engram, y archivos locales en `.claude/memory/`), **hooks de seguridad** que bloquean operaciones peligrosas antes de que pasen, y **24 skills tecnicas** que enseñan a los agentes las mejores practicas de cada tecnologia.

## Instalacion

### Requisitos

- Claude Code instalado y autenticado
- Python 3.10+
- jq

### Instalar (una sola vez, para siempre)

1. Abri Claude Code:
   ```bash
   claude
   ```

2. Adentro, abri el panel de plugins:
   ```
   /plugins
   ```

3. Anda a **Marketplaces** → **Add Marketplace** y pone:
   ```
   JuaniSarmiento/Ecosistema-Claude
   ```

4. Volve a **Discover**, busca `claude-gentleman-native` y dale instalar.

5. Cerra Claude y abrilo de nuevo. Listo.

### Verificar instalacion

Adentro de Claude:
```
/plugins
```
Deberia aparecer `claude-gentleman-native · ✔ enabled`.

## Que incluye

### Agentes (8)

| Agente | Rol | Modelo |
|--------|-----|--------|
| `gentleman-orchestrator` | Coordinador general, delega todo | Sonnet |
| `explorer` | Investiga codebase sin modificar nada | Haiku |
| `specifier` | Convierte necesidades en specs con criterios de aceptacion | Sonnet |
| `designer` | Diseña arquitectura e interfaces | Sonnet |
| `implementer` | Implementa cambios siguiendo spec y diseño | Sonnet |
| `verifier` | Verificacion tecnica y QA | Haiku |
| `code-reviewer` | Revisa legibilidad, convenciones y deuda tecnica | Sonnet |
| `security-reviewer` | Revisa secretos, permisos y riesgos operativos | Sonnet |

### Skills (24)

**SDD — Workflow estructurado (9):**
`sdd-init` · `sdd-explore` · `sdd-propose` · `sdd-spec` · `sdd-design` · `sdd-tasks` · `sdd-apply` · `sdd-verify` · `sdd-archive`

**Tecnicas (15):**
`typescript-strict` · `react-19` · `nextjs-15` · `tailwind-4` · `zustand-5` · `testing-vitest` · `playwright` · `prisma-drizzle` · `api-rest` · `docker` · `ci-cd` · `git-conventions` · `monorepo` · `accessibility` · `pr-review`

### Hooks de seguridad

- **Proteccion de archivos**: bloquea ediciones a `.env`, `.secrets`, `.pem`, `.key`, `.git/`, `.claude/settings.json`
- **Politica de git**: bloquea `git reset --hard`, `git clean -fd`, `git push -f`
- **Inyeccion de memoria**: carga contexto de `.claude/memory/` al iniciar sesion
- **Auditoria de config**: registra cambios de configuracion en log
- **Quality gate**: antes de cerrar una tarea, verifica que lint y tests pasen

### Memoria persistente

Funciona con dos capas sin dependencias externas:
- **Engram** (SQLite + FTS5): busqueda full-text, summaries de sesion, topic keys para recuperar contexto entre sesiones
- **Project Memory** (MCP server Python incluido): archivos en `.claude/memory/` para convenciones, decisiones y contexto del proyecto

## Como se usa

### Para cambios grandes → SDD
```
Quiero agregar autenticacion con JWT. Usa SDD.
```
Activa el pipeline completo: explore → propose → spec → design → tasks → implement → verify → archive.

### Para cambios chicos → Directo
```
Agrega un endpoint GET /health que devuelva 200.
```
El orquestador delega directo al implementer.

### La memoria funciona sola

Guarda decisiones, bugs y descubrimientos automaticamente. La proxima sesion, Claude recuerda todo.

## Para desarrolladores del plugin

### Clonar y desarrollar
```bash
git clone https://github.com/JuaniSarmiento/Ecosistema-Claude.git
cd Ecosistema-Claude
```

### Estructura del repo
```
├── .claude-plugin/
│   └── marketplace.json     # Registro del marketplace
├── plugin/                  # El plugin propiamente dicho
│   ├── .claude-plugin/
│   │   └── plugin.json      # Metadata del plugin
│   ├── agents/              # 8 agentes especializados
│   ├── skills/              # 24 skills (SDD + tecnicas)
│   ├── hooks/               # Hooks de seguridad
│   ├── servers/             # MCP server de memoria (Python, stdlib)
│   ├── templates/           # Templates para bootstrapear proyectos
│   ├── scripts/             # Installer, status, bootstrap
│   ├── tests/               # Tests de hooks
│   ├── .mcp.json
│   ├── settings.json
│   └── Makefile
├── CLAUDE.md
└── README.md
```

### Comandos de desarrollo

| Comando | Que hace |
|---------|----------|
| `make dev` | Lanza Claude con el plugin local |
| `make test-hooks` | Corre tests de hooks |
| `make verify-env` | Verifica que `claude`, `python3` y `jq` esten disponibles |
| `make bootstrap` | Inicializa `.claude/memory/`, `.claude/specs/` y `AGENTS.md` en el proyecto |
| `make smoke` | Checklist de smoke tests manuales |

## Licencia

MIT
