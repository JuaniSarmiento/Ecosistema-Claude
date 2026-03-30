# Documentación técnica completa — Claude Gentleman Native v1

## 1. Propósito

Claude Gentleman Native v1 es un ecosistema **Claude-only** diseñado para reproducir el núcleo funcional del PRD de Gentle AI dentro de Claude Code, usando únicamente capacidades nativas documentadas del producto: **plugins, subagents, hooks, skills y MCP servers**. El objetivo es transformar a Claude Code desde un agente base hacia un entorno de trabajo con **memoria persistente, flujo SDD, roles especializados, guardrails de seguridad y verificación antes del cierre**. El PRD de Gentle AI plantea justamente esa combinación de memoria, workflow, skills, seguridad y persona como el corazón del ecosistema. citeturn0search0turn0open0

## 2. Correspondencia funcional con Gentle AI

El diseño replica cinco capacidades principales del PRD:

### 2.1 Memoria persistente
La propuesta usa dos capas:
- `memory: project` en subagents, aprovechando la memoria persistente soportada por Claude Code.
- archivos explícitos en `.claude/memory/`, reinjectados al contexto mediante `SessionStart` hooks.

Claude Code documenta tanto la memoria persistente por scope de subagent como la reinyección de contexto con hooks al inicio, reanudación o compaction. citeturn0search1turn0search2

### 2.2 Spec-Driven Development
El flujo SDD se empaqueta como biblioteca de skills:
- `sdd-init`
- `sdd-explore`
- `sdd-propose`
- `sdd-spec`
- `sdd-design`
- `sdd-tasks`
- `sdd-apply`
- `sdd-verify`
- `sdd-archive`

Claude Code documenta que los plugins pueden empaquetar skills y que estas pueden ser invocadas explícita o automáticamente por el modelo cuando el contexto las haga relevantes. citeturn0search1

### 2.3 Equipo de agentes especializados
La propuesta define:
- `gentleman-orchestrator`
- `explorer`
- `specifier`
- `designer`
- `implementer`
- `verifier`
- `code-reviewer`
- `security-reviewer`

Claude Code documenta que los subagents tienen ventana de contexto propia, herramientas independientes y memoria persistente por scope. También aparecen en `/agents` y pueden limitar tools o usar skills específicas. citeturn0search3

### 2.4 Guardrails de seguridad
La política de seguridad descansa en hooks:
- bloqueo de edición sobre `.env`, `.pem`, `.key`, `.git/`, `.claude/settings.json`
- bloqueo de operaciones git destructivas como `git reset --hard` o `git push --force`
- auditoría de cambios de configuración con `ConfigChange`

Claude Code documenta `PreToolUse`, `ConfigChange`, `permissionDecision: "deny"` y el patrón de filtrado sobre Bash para comandos git. citeturn0search2

### 2.5 Quality gate
El quality gate usa un `Stop` hook de tipo `agent`, pensado para verificar que la tarea esté lista antes de cerrarse. Claude Code documenta los `Stop` hooks y advierte que deben manejar `stop_hook_active` para evitar bucles. citeturn0search2

## 3. Arquitectura

La arquitectura se apoya en cinco capas:

1. **Plugin root**: empaqueta manifiesto, settings, agents, skills, hooks y MCP.
2. **Orquestación**: `gentleman-orchestrator` decide cuándo activar SDD y qué subagent delegar.
3. **Especialización**: subagents reducen ruido de contexto y separan responsabilidades.
4. **Enforcement**: hooks introducen reglas deterministas, no solo buenas intenciones por prompt.
5. **Persistencia**: memoria de proyecto en archivos y memoria nativa de subagent.

Esta separación es importante porque la referencia oficial aclara que los agents empaquetados por plugins **no** soportan `hooks`, `mcpServers` ni `permissionMode` en su frontmatter; esas responsabilidades deben residir fuera del agent, en hooks, MCP y settings del plugin. citeturn0search1

## 4. Estructura del repositorio

El repositorio se organiza así:

- `.claude-plugin/plugin.json`: manifiesto del plugin.
- `settings.json`: activa el agente principal.
- `.mcp.json`: registra un servidor MCP local.
- `agents/`: define agentes especializados.
- `skills/`: encapsula SDD y buenas prácticas técnicas.
- `hooks/`: impone seguridad, memoria y verificación.
- `servers/`: implementa el MCP local `project-memory`.
- `templates/`: inicializa memoria, specs y reglas de proyecto.
- `scripts/`: bootstrap, verificación y empaquetado.
- `tests/`: harness reproducible para hooks.

Las ubicaciones de `plugin.json`, `settings.json`, `.mcp.json`, `agents/`, `skills/` y `hooks/hooks.json` son consistentes con la referencia oficial de plugins. citeturn0search1

## 5. Archivo por archivo

### 5.1 `plugin.json`
Define:
- nombre del plugin
- descripción
- versión
- autor
- `userConfig`

`userConfig` permite parametrizar `test_command`, `lint_command` y `docs_glob` sin modificar manualmente el plugin. Claude Code documenta `userConfig` y su exposición a procesos del plugin como variables de entorno o placeholders. citeturn0search1

### 5.2 `settings.json`
Contiene:
```json
{
  "agent": "gentleman-orchestrator"
}
```
La referencia oficial indica que `settings.json` del plugin soporta `agent` como forma de activar el agente por defecto del plugin. citeturn0search1

### 5.3 `.mcp.json`
Registra el servidor local `project-memory`, ejecutado con `python3`. La referencia oficial de plugins soporta `.mcp.json` dentro del plugin y permite referenciar `${CLAUDE_PLUGIN_ROOT}` y valores de `userConfig`. citeturn0search1

### 5.4 `agents/`
Los agentes se diseñan con prompts y toolsets diferenciados:
- `explorer`: solo lectura e investigación.
- `specifier`: definición de alcance y aceptación.
- `designer`: diseño técnico.
- `implementer`: implementación.
- `verifier`: verificación técnica.
- `code-reviewer`: revisión de calidad.
- `security-reviewer`: revisión de seguridad.

La documentación de subagents avala el uso de tool restrictions, memory scopes y context windows separadas. citeturn0search3

### 5.5 `skills/`
Incluyen:
- nueve skills SDD
- cuatro skills técnicas
- una skill de `pr-review`

Claude Code documenta que las skills pueden vivir dentro de plugins y ser invocadas por el modelo cuando correspondan. citeturn0search1

### 5.6 `hooks/`
- `protect-files.sh`
- `check-git-policy.sh`
- `memory-inject.sh`
- `memory-snapshot.sh`
- `audit-config.sh`
- `stop-verify.sh`

Los hooks implementan políticas reales:
- bloquear edición de secretos
- bloquear git destructivo
- reinyectar memoria
- auditar configuración
- controlar cierre de tareas

Todo esto está directamente soportado por los eventos documentados en la guía de hooks. citeturn0search2

### 5.7 `project_memory_server.py`
Este MCP local ofrece herramientas para:
- listar documentación markdown
- leer memoria explícita
- escribir memoria explícita

No reemplaza completamente a Engram, pero sí crea una capa MCP local para exponer memoria y documentación del proyecto. La referencia oficial de plugins soporta MCP servers empaquetados dentro del plugin. citeturn0search1

## 6. Flujo operativo

El flujo recomendado es:

1. Ejecutar `make verify-env`
2. Ejecutar `make bootstrap`
3. Lanzar `claude --plugin-dir ./claude-gentleman-native`
4. Verificar `/help`, `/agents`, `/hooks`
5. Trabajar con el agente principal

Cuando una tarea no es trivial, `gentleman-orchestrator` debería activar el flujo SDD. Luego puede delegar:
- exploración → `explorer`
- especificación → `specifier`
- diseño → `designer`
- implementación → `implementer`
- verificación → `verifier`
- revisión → `code-reviewer` y `security-reviewer`

## 7. Verificación

### 7.1 Verificación estática
- `make verify-env`
- `make test-hooks`

### 7.2 Verificación interactiva
- `/help` debe mostrar skills del plugin.
- `/agents` debe mostrar subagents.
- `/hooks` debe mostrar hooks cargados.
- `/reload-plugins` debe recargar cambios del plugin local.

Claude Code documenta este flujo de validación durante desarrollo de plugins. citeturn0search4

### 7.3 Casos de prueba funcionales
1. Pedir editar `.env`: debe bloquearse.
2. Pedir ejecutar `git reset --hard`: debe bloquearse.
3. Escribir una convención en `.claude/memory/conventions.md`, reiniciar y pedirla: debe recuperarse.
4. Intentar cerrar una tarea con verificación incompleta: el `Stop` hook debe intervenir.

## 8. Troubleshooting

Si Claude no carga el plugin o se comporta de forma extraña:
- ejecutar `which -a claude`
- comprobar `claude --version`
- revisar instalaciones duplicadas en PATH

La guía de troubleshooting recomienda expresamente revisar instalaciones conflictivas con `which -a claude` y diferenciar entre instalaciones nativas y de npm. citeturn0search5

## 9. Limitaciones conocidas

Esta propuesta reproduce de forma alta el núcleo del PRD, pero con dos límites importantes:

1. **Claude-only**: no ofrece la capa multiagente del PRD original.
2. **Memoria no idéntica a Engram**: la memoria híbrida de subagent + archivos + MCP local es útil y verificable, pero no es una réplica total de Engram.

## 10. Valor práctico

Aun con esas limitaciones, la propuesta sí entrega:
- una experiencia de mentoría coherente;
- flujo SDD integrado;
- guardrails fuertes;
- memoria persistente verificable;
- especialización por agentes;
- y una compuerta de calidad antes del cierre.

Eso coincide con el espíritu operacional del PRD de Gentle AI, pero aterrizado en el marco oficial y verificable de Claude Code. citeturn0search0turn0open0turn0search1turn0search2turn0search3
