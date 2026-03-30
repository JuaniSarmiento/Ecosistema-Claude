---
name: sdd-apply
description: Implementa siguiendo la especificacion y el diseno, sin desviaciones innecesarias.
---

## Antes de Cambiar Codigo

- Recuerda el objetivo
- Recuerda los criterios de aceptacion
- Evita scope creep

## Durante la Implementacion

- Minimiza cambios
- Respeta convenciones
- Deja el sistema mas claro, no mas confuso

## Lectura de Dependencias

Lee tasks, spec Y design con `mem_search`:
1. query: `sdd/{change-name}/tasks` -> `mem_get` con el ID
2. query: `sdd/{change-name}/spec` -> `mem_get` con el ID
3. query: `sdd/{change-name}/design` -> `mem_get` con el ID

Si falta alguna dependencia critica (tasks es obligatorio), DETENTE y reporta.

## Escritura a Memoria

Despues de cada batch de tareas completado, actualiza progreso con `mem_save`:
- **topic_key**: `sdd/{change-name}/apply-progress`
- **type**: `architecture`
- **content**: tareas completadas, tareas pendientes, decisiones de implementacion, problemas encontrados

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (archivos modificados, tareas completadas), `next_recommended` (verify), `risks`.
