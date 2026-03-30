# Claude Gentleman Native

Plugin de Claude Code que replica el núcleo del ecosistema Gentleman dentro de Claude:

- workflow SDD
- subagents especializados
- skills técnicas
- memoria persistente de proyecto
- hooks de seguridad
- quality gate antes de cerrar una tarea

## Requisitos

- Claude Code instalado y autenticado
- Python 3
- jq
- Claude Code con soporte de plugins

## Verificación de entorno

```bash
make verify-env
```

## Inicializar un proyecto

```bash
make bootstrap
```

Eso crea:

- `.claude/memory/`
- `.claude/specs/`
- `AGENTS.md`

## Probar localmente

```bash
make dev
```

Dentro de Claude:

- `/help`
- `/agents`
- `/hooks`
- `/reload-plugins`

## Pruebas

```bash
make test-hooks
make smoke
```

## Verificaciones recomendadas

1. Pedir editar `.env` y confirmar que lo bloquea.
2. Pedir `git reset --hard` y confirmar que lo bloquea.
3. Crear `.claude/memory/conventions.md`, reiniciar y verificar que Claude lo recuerde.
4. Forzar una tarea con tests rotos y comprobar que el cierre falle.
