# Claude Gentleman Native — Explicación completa del proyecto

## La idea central

Este proyecto es una propuesta para replicar el ecosistema completo de Gentleman AI —un entorno de desarrollo asistido por inteligencia artificial con metodología estructurada, memoria persistente, seguridad y mentoría técnica— utilizando exclusivamente las capacidades nativas de Claude Code. No es una aplicación web, no es un backend, no se compila ni se transpila. Es un **plugin de Claude Code**: un paquete de archivos Markdown, scripts Bash, configuración JSON y un pequeño servidor Python que, al ser cargado por Claude Code, transforma al asistente en un equipo completo de desarrollo con roles especializados, flujo de trabajo riguroso y políticas de seguridad activas.

La premisa filosófica del proyecto es que la inteligencia artificial no debe ser un reemplazo del desarrollador, sino una herramienta que el humano dirige con criterio. Para que esa dirección sea efectiva, el asistente necesita estructura: saber cuándo explorar y cuándo implementar, cuándo pedir especificaciones y cuándo escribir código, cuándo verificar y cuándo cerrar. Gentleman Native le da esa estructura a Claude Code.

---

## La arquitectura general

El plugin se organiza en seis capas que cooperan entre sí:

1. **Agentes** — ocho perfiles especializados que definen quién hace qué.
2. **Skills** — quince conjuntos de instrucciones que definen cómo se hace cada tipo de trabajo.
3. **Hooks** — cuatro puntos de intercepción que definen qué está prohibido y qué se verifica automáticamente.
4. **Memoria** — un sistema híbrido que permite a Claude recordar decisiones, convenciones y contexto entre sesiones.
5. **MCP Server** — un servidor local que expone la memoria del proyecto como herramientas invocables.
6. **Templates** — plantillas que inicializan la estructura de memoria y especificaciones en cualquier proyecto nuevo.

Cada capa es independiente pero se potencia con las demás. Los agentes usan skills para saber cómo trabajar. Los hooks protegen lo que los agentes tocan. La memoria alimenta el contexto de cada sesión. El MCP server hace que la memoria sea accesible programáticamente. Las templates arrancan todo desde cero cuando se ejecuta `make bootstrap`.

---

## Los agentes: un equipo virtual con roles claros

El corazón del ecosistema es el **gentleman-orchestrator**, un agente configurado como arquitecto senior y mentor técnico. Este agente no escribe código directamente. Su trabajo es coordinar: recibe la solicitud del usuario, evalúa su complejidad, decide si requiere un flujo estructurado (SDD) o una intervención simple, y delega el trabajo real a agentes especializados.

Los agentes especializados son siete:

**El explorer** es el investigador. Opera con el modelo más liviano (Haiku) porque su trabajo es rápido y de solo lectura: recorrer archivos, entender dependencias, identificar restricciones, detectar riesgos y formular preguntas abiertas. Tiene prohibido editar o escribir archivos. Su producto es información para que los otros agentes tomen decisiones informadas.

**El specifier** toma una necesidad vaga y la convierte en una especificación formal. Define el objetivo, el alcance, lo que queda fuera de alcance, los criterios de aceptación verificables, los casos borde, los riesgos y las dudas pendientes. Sin esta especificación, el implementador no debería tocar código — esa es la filosofía del proyecto.

**El designer** recibe la especificación y produce un diseño técnico: qué componentes se ven afectados, qué cambios se necesitan por módulo, qué interfaces o contratos hay que respetar, cómo fluyen los datos, qué impacto tiene en las pruebas existentes, y cómo se puede revertir si algo sale mal. Opera con acceso al modo de planificación de Claude Code para estructurar su pensamiento.

**El implementer** es el único agente que realmente escribe código. Tiene acceso a las herramientas de edición, escritura, lectura y ejecución de comandos. Pero no trabaja en el vacío: recibe una especificación y un diseño aprobados, y sus instrucciones le exigen cambios mínimos y coherentes, sin debilitar tipos ni introducir complejidad innecesaria. Además, tiene cargadas tres skills técnicas específicas: TypeScript estricto, React 19 y Next.js 15, que guían sus decisiones de código.

**El verifier** es el control de calidad. Opera con Haiku porque su trabajo es mecánico y rápido: verificar que los criterios de aceptación se cumplan, que las pruebas pasen, que el linter no reporte errores, que no haya warnings críticos, y que el cambio sea coherente. Tiene acceso a la skill de Playwright para pruebas end-to-end y a la skill de verificación SDD. Su producto es un veredicto explícito: pasa o no pasa.

**El code-reviewer** evalúa la calidad del código desde una perspectiva más amplia: claridad, acoplamiento, deuda técnica, consistencia con los patrones del proyecto y cobertura de pruebas. No busca errores funcionales (eso es trabajo del verifier) sino problemas de mantenibilidad a largo plazo.

**El security-reviewer** busca vulnerabilidades: secretos y credenciales expuestos, validación insuficiente de entradas, acceso a archivos sensibles, operaciones destructivas sin confirmación, y fugas de información. Es la última barrera antes de que un cambio se considere completo.

Cada agente se define en un archivo Markdown dentro de la carpeta `agents/`. La parte superior del archivo es frontmatter YAML que declara el nombre, la descripción, el modelo de lenguaje a usar, el nivel de esfuerzo, el número máximo de turnos, las herramientas permitidas o prohibidas, las skills cargadas y si debe usar memoria persistente. El cuerpo del archivo son las instrucciones en lenguaje natural que Claude Code interpreta como la personalidad y directivas del agente.

---

## Las skills: el conocimiento codificado

Si los agentes son los roles, las skills son el conocimiento técnico que esos roles necesitan para hacer bien su trabajo. Cada skill es un archivo `SKILL.md` dentro de una carpeta con su nombre bajo `skills/`.

Las skills se dividen en dos familias:

### Skills de flujo SDD

Nueve skills que cubren cada fase del desarrollo estructurado:

**sdd-init** clasifica el tipo de cambio, determina si requiere exploración, especificación o diseño, define el objetivo principal, delimita el alcance inicial y propone la secuencia de fases adecuada. Es el punto de entrada que decide cuántas fases del pipeline se necesitan.

**sdd-explore** guía la investigación previa: archivos relevantes, dependencias, restricciones, comportamientos actuales, huecos de conocimiento y riesgos. Su regla cardinal es no implementar nada todavía.

**sdd-propose** exige que se listen opciones razonables, se expliquen ventajas y costos de cada una, se elija una recomendación y se justifique por qué se descartan las alternativas. Fuerza el pensamiento crítico antes de comprometerse con una solución.

**sdd-spec** produce la especificación funcional y técnica completa: objetivo, alcance, fuera de alcance, criterios de aceptación, casos borde, dependencias, riesgos y preguntas abiertas.

**sdd-design** define la arquitectura de la solución: cambios por módulo, interfaces, flujo de datos, validaciones, impacto en pruebas, y estrategia de rollback o mitigación.

**sdd-tasks** divide la implementación en tareas atómicas, secuenciales o paralelizables, cada una con criterio de finalización y archivos implicados.

**sdd-apply** guía la implementación propiamente dicha. Antes de tocar código, recuerda el objetivo y los criterios de aceptación. Durante la implementación, minimiza cambios, respeta convenciones y exige que el sistema quede más claro, no más confuso.

**sdd-verify** verifica criterios de aceptación, lint, tests relevantes, errores obvios, warnings críticos, riesgos restantes y deuda técnica nueva.

**sdd-archive** cierra el cambio registrando qué se hizo, las decisiones relevantes, los follow-ups pendientes y actualiza la memoria del proyecto.

El pipeline completo forma un grafo de dependencias: la propuesta alimenta a la especificación, que junto con el diseño alimentan las tareas, que guían la implementación, que pasa por verificación y finalmente se archiva. No es un proceso rígido — el orchestrator puede saltar fases si el cambio es simple — pero la estructura existe para que los cambios complejos no se pierdan en la improvisación.

### Skills técnicas

Cinco skills que codifican buenas prácticas de tecnologías específicas:

**typescript-strict** prohíbe el uso de `any` sin justificación, exige modelar la nullability con claridad, no permite desactivar checks del compilador para hacer pasar la compilación, y prioriza tipos legibles y mantenibles.

**react-19** promueve evitar efectos innecesarios, minimizar estado derivable, separar UI de lógica y datos, y usar composición antes que complejidad accidental.

**nextjs-15** exige decidir con claridad qué corre en servidor y qué en cliente, minimizar la complejidad del data fetching, respetar los límites de routing y caché, y no acoplar UI con infraestructura.

**playwright** guía la escritura de pruebas end-to-end: probar comportamiento y no implementación interna, evitar sleeps innecesarios, priorizar selectores robustos y mantener flujos de prueba claros.

**pr-review** define un checklist de revisión previo al cierre: releer objetivo y criterios de aceptación, revisar el diff por módulo, identificar riesgos técnicos, de seguridad y de mantenimiento, confirmar si faltan pruebas o documentación, y emitir un veredicto explícito (listo, listo con follow-ups, o no listo).

---

## Los hooks: las barreras automáticas

Los hooks son el sistema de seguridad y verificación automática del plugin. Se definen en `hooks/hooks.json` y se ejecutan como scripts Bash que reciben JSON por stdin y devuelven JSON por stdout.

Hay cuatro tipos de hooks registrados:

### Protección de archivos (PreToolUse en Edit/Write)

Cada vez que Claude intenta editar o escribir un archivo, el script `protect-files.sh` intercepta la operación y verifica si la ruta contiene alguno de los patrones protegidos: `.env`, `.secrets`, `.pem`, `.key`, `.p12`, `.git/` o `.claude/settings.json`. Si la ruta coincide, el hook devuelve un JSON con `permissionDecision: "deny"` y una razón explicativa. Claude Code recibe esta denegación y no puede completar la operación. El usuario nunca corre el riesgo de que el asistente modifique accidentalmente archivos sensibles.

### Política de Git (PreToolUse en Bash con comandos git)

Cada vez que Claude intenta ejecutar un comando git, el script `check-git-policy.sh` lo intercepta y compara contra una lista de operaciones destructivas prohibidas: `git reset --hard`, `git clean -fd`, `git clean -fdx`, `git push --force` y `git push -f`. Si el comando coincide, se deniega con una explicación. Esto previene que el asistente destruya historial, borre archivos no rastreados o fuerce pushes que sobreescriban el trabajo remoto.

### Inyección de memoria (SessionStart)

Cada vez que se inicia una sesión, se reanuda o se compacta el contexto, el script `memory-inject.sh` busca archivos de memoria en `.claude/memory/` del proyecto actual. Si encuentra `conventions.md`, `current-work.md`, `decisions.md` u `open-questions.md`, inyecta las primeras 200 líneas de cada uno en el contexto de la sesión. Esto permite que Claude arranque cada conversación con conocimiento de las convenciones del proyecto, el trabajo en curso, las decisiones tomadas y las preguntas pendientes, sin que el usuario tenga que repetir nada.

### Auditoría de configuración (ConfigChange)

Cada vez que cambia la configuración, el script `audit-config.sh` registra el evento en un archivo de log (`~/claude-gentleman-config-audit.log`) con timestamp, fuente y ruta del archivo afectado. Es una traza de auditoría silenciosa que permite rastrear cambios de configuración en el tiempo.

### Puerta de calidad (Stop)

Cuando Claude intenta cerrar una tarea, un hook de tipo agente (no un script) se activa con un timeout de 180 segundos. Este agente recibe la instrucción de verificar que la tarea esté realmente lista: lee el diff, ejecuta lint y tests usando los comandos configurados, y compara los resultados contra los criterios de aceptación. Si algo falla, devuelve `{"ok": false, "reason": "..."}` y la tarea no se cierra. Si todo está correcto, devuelve `{"ok": true}`. Esta es quizás la pieza más poderosa del sistema de hooks: garantiza que ningún trabajo se dé por terminado sin verificación técnica real.

---

## La memoria: persistencia entre sesiones

Uno de los problemas fundamentales de los asistentes de IA es la amnesia entre sesiones. Cada conversación nueva empieza de cero. Gentleman Native ataca este problema con una estrategia de memoria de tres niveles:

### Agent Memory (nativa de Claude Code)

Cada agente puede declarar `memory: project` en su frontmatter, lo que hace que Claude Code persista automáticamente información relevante en `~/.claude/agent-memory/{nombre-del-agente}/`. Esta es la forma más simple de persistencia: no requiere configuración adicional ni dependencias externas. El agente recuerda convenciones, decisiones y contexto del proyecto de forma transparente.

### Engram MCP (opcional)

Para proyectos que necesitan búsqueda full-text, resúmenes de sesión, claves de tópico y recuperación cross-session más sofisticada, el ecosistema es compatible con Engram, un servidor MCP externo de memoria persistente. Engram permite guardar observaciones con tipo (bugfix, decisión, arquitectura, descubrimiento), buscar por palabras clave, agrupar información por topic keys, y generar resúmenes de sesión que alimentan la sesión siguiente.

### Project Memory MCP (incluido en el plugin)

El plugin incluye su propio servidor MCP escrito en Python (`servers/project_memory_server.py`) que expone tres herramientas:

**list_docs** devuelve una lista de hasta 200 archivos Markdown del proyecto, filtrados por el glob configurado en `docs_glob`. Permite al asistente saber qué documentación existe sin tener que buscar manualmente.

**read_memory** lee un archivo específico de `.claude/memory/`. Permite al asistente consultar convenciones, decisiones, trabajo en curso o preguntas abiertas programáticamente.

**write_memory** escribe contenido en un archivo de `.claude/memory/`. Permite al asistente actualizar la memoria del proyecto como parte de su flujo de trabajo normal.

El servidor es minimalista por diseño: un loop que lee líneas JSON-RPC 2.0 por stdin, despacha métodos (`initialize`, `tools/list`, `tools/call`), y devuelve resultados por stdout. No tiene dependencias externas más allá de la librería estándar de Python 3. Se declara en `.mcp.json` y Claude Code lo arranca automáticamente al cargar el plugin.

---

## Las templates: el arranque limpio

Cuando se ejecuta `make bootstrap`, el script `scripts/bootstrap-project.sh` copia un conjunto de plantillas al proyecto actual:

En `.claude/memory/` se crean cuatro archivos:

- **conventions.md** — para documentar el package manager oficial, la convención de ramas, las suites de prueba obligatorias y las reglas de estilo y arquitectura.
- **decisions.md** — un log de decisiones de arquitectura, convenciones y trade-offs.
- **current-work.md** — el objetivo activo, las tareas en progreso y los bloqueos conocidos.
- **open-questions.md** — dudas no resueltas, marcando cuáles bloquean implementación y cuáles no.

En `.claude/specs/` se crean tres templates:

- **spec-template.md** — plantilla de especificación con objetivo, alcance, fuera de alcance, criterios de aceptación, casos borde, riesgos y preguntas abiertas.
- **design-template.md** — plantilla de diseño con módulos afectados, arquitectura propuesta, flujo de datos, interfaces, validación, impacto en pruebas y estrategia de rollback.
- **tasks-template.md** — checklist de tareas que refleja el pipeline SDD completo.

En la raíz del proyecto se crea **AGENTS.md**, un archivo de estándares de equipo que define políticas de seguridad (no editar secretos, no hacer operaciones git destructivas), calidad de código (claridad sobre cleverness, minimizar scope creep, exigir verificación) y flujo de trabajo (usar SDD para cambios no triviales, registrar decisiones en memoria).

Estos archivos no son decorativos. El hook de `SessionStart` los inyecta al contexto, los agentes los consultan para tomar decisiones, y el MCP server los expone como herramientas. Son la memoria viva del proyecto.

---

## La configuración del plugin

Tres archivos JSON configuran cómo Claude Code carga y ejecuta el plugin:

### plugin.json

Declara el nombre (`claude-gentleman-native`), la descripción, la versión y el esquema de configuración del usuario. El usuario puede definir tres valores:

- `test_command` — el comando que ejecuta las pruebas del proyecto (por ejemplo, `npm test` o `pytest`).
- `lint_command` — el comando de linting (por ejemplo, `eslint .` o `ruff check`).
- `docs_glob` — el patrón glob para indexar documentación del proyecto (por defecto `**/*.md`).

Estos valores son usados por el MCP server y por el hook de Stop para saber qué ejecutar al verificar una tarea.

### .mcp.json

Declara el servidor MCP `project-memory` con el comando `python3`, la ruta al script del servidor (relativa a `CLAUDE_PLUGIN_ROOT`), y la variable de entorno `DOCS_GLOB` tomada de la configuración del usuario.

### settings.json

Define que el agente por defecto al cargar el plugin es `gentleman-orchestrator`. Esto significa que cuando el usuario ejecuta `make dev`, Claude Code arranca con la personalidad del arquitecto senior orquestador.

---

## Los scripts de soporte

### verify-env.sh

Verifica que las tres dependencias del plugin estén instaladas: `claude` (Claude Code), `python3` y `jq`. Muestra la versión de Claude Code y cualquier instalación potencialmente conflictiva.

### bootstrap-project.sh

Crea la estructura de directorios (`.claude/memory/`, `.claude/specs/`), copia las templates sin sobreescribir archivos existentes (usa `cp -n`), y genera `AGENTS.md` en la raíz si no existe. Acepta un argumento opcional para especificar un directorio distinto al actual.

### package-plugin.sh

Empaqueta todo el plugin en un archivo `dist/claude-gentleman-native.tar.gz`, incluyendo la configuración del plugin, los agentes, las skills, los hooks, el servidor, las templates, los scripts y los tests. Este archivo es lo que se distribuye para que otros equipos instalen el plugin.

---

## Las pruebas

El proyecto incluye dos niveles de verificación:

### Tests automatizados de hooks

`tests/test-hooks.sh` ejecuta tres pruebas unitarias:

1. Verifica que `protect-files.sh` deniega la edición de archivos `.env`, alimentando un fixture JSON que simula un `PreToolUse` de tipo `Edit` con ruta `/tmp/demo/.env`.
2. Verifica que `check-git-policy.sh` deniega `git reset --hard`, alimentando un fixture JSON que simula un `PreToolUse` de tipo `Bash` con ese comando.
3. Verifica que `memory-inject.sh` inyecta el contenido de `conventions.md`, creando un directorio temporal con un archivo de memoria y comprobando que la salida contiene el texto esperado.

Los fixtures son archivos JSON mínimos en `tests/fixtures/` que simulan los payloads que Claude Code envía a los hooks.

### Smoke test manual

`tests/smoke-plugin.sh` imprime instrucciones para verificar interactivamente dentro de Claude Code que el plugin está cargado correctamente, ejecutando `/help`, `/agents`, `/hooks` y `/reload-plugins`.

---

## El documento de ecosistema

`ecosistema.md` es la especificación madre del proyecto: un documento de 817 líneas en español que detalla la visión completa de cómo replicar Gentleman AI usando Claude Code nativo. Cubre la arquitectura general, cada componente en detalle (memoria, MCP, skills, SDD, permisos, code review, persona, plugin), una tabla de equivalencia entre las capacidades del PRD original de Gentleman AI y sus implementaciones nativas en Claude Code, las limitaciones conocidas y alternativas, un plan de implementación en cinco fases, y comandos de verificación rápida.

Este documento es el blueprint del que se derivó todo el código del plugin. Es la referencia definitiva para entender no solo qué hace cada pieza, sino por qué existe y qué problema resuelve del ecosistema original.

---

## El flujo completo de un cambio

Para entender cómo todas estas piezas trabajan juntas, veamos el recorrido de un cambio no trivial:

1. El usuario describe lo que necesita al **orchestrator**.
2. El orchestrator evalúa la complejidad y activa SDD (**sdd-init**).
3. Delega al **explorer** que investigue el estado actual del sistema (**sdd-explore**).
4. Con la información del explorer, el orchestrator delega al **specifier** que produzca la especificación (**sdd-spec**), posiblemente pasando primero por **sdd-propose** para evaluar alternativas.
5. La especificación llega al **designer** que produce el diseño técnico (**sdd-design**).
6. El orchestrator divide el trabajo en tareas (**sdd-tasks**).
7. El **implementer** ejecuta cada tarea siguiendo la especificación y el diseño (**sdd-apply**), guiado por las skills técnicas de TypeScript, React y Next.js.
8. Durante la implementación, si Claude intenta editar un archivo protegido, **protect-files.sh** lo bloquea. Si intenta un comando git destructivo, **check-git-policy.sh** lo detiene.
9. El **verifier** valida que los criterios de aceptación se cumplan (**sdd-verify**).
10. El **code-reviewer** evalúa la calidad del código.
11. El **security-reviewer** busca vulnerabilidades.
12. El orchestrator intenta cerrar la tarea. El hook **Stop** activa un agente verificador que ejecuta lint, tests y compara contra los criterios. Si algo falla, la tarea no se cierra.
13. Si todo pasa, se archiva el cambio (**sdd-archive**), registrando decisiones y follow-ups en la memoria del proyecto.
14. La próxima sesión, el hook de **SessionStart** inyecta esa memoria, y Claude arranca sabiendo todo lo que pasó antes.

---

## Lo que este proyecto NO es

No es una aplicación que los usuarios finales van a usar. No tiene interfaz gráfica, no tiene API HTTP, no tiene base de datos. No se despliega en ningún servidor.

Es una **herramienta para desarrolladores que usan Claude Code**. Transforma al asistente en un equipo estructurado con metodología, memoria y seguridad. Es, en esencia, la codificación de una forma de trabajar — la forma de trabajar de Gentleman AI — en un formato que Claude Code puede interpretar y ejecutar.

La propuesta de valor es que un desarrollador que instale este plugin obtiene, sin configuración adicional, un asistente que no improvisa: que investiga antes de implementar, que especifica antes de diseñar, que diseña antes de codear, que verifica antes de cerrar, y que recuerda lo que aprendió para la próxima vez.
