---
name: sdd-archive
description: Cierra el cambio registrando decisiones, riesgos resueltos y pendientes.
---

## Al Cerrar

- Resume que se hizo
- Registra decisiones relevantes
- Anota follow-ups
- Actualiza memoria del proyecto

## Deteccion de Backend de Memoria

Antes de cualquier operacion de persistencia, detecta que backend esta disponible:

1. Verifica si las herramientas de memoria (`mem_save`, `mem_search`) estan disponibles — pueden ser provistas por el MCP server `gentleman-memory` o `engram`. Ambos exponen la misma API.
2. Si alguna herramienta de memoria esta disponible -> usa modo `engram` (memoria persistente).
3. Si ninguna herramienta de memoria esta disponible -> usa modo `openspec` (archivos en disco).

## Lectura de Dependencias

Lee TODOS los artefactos del cambio con `mem_search`:
1. query: `sdd/{change-name}/proposal` -> `mem_get` con el ID
2. query: `sdd/{change-name}/spec` -> `mem_get` con el ID
3. query: `sdd/{change-name}/design` -> `mem_get` con el ID
4. query: `sdd/{change-name}/tasks` -> `mem_get` con el ID
5. query: `sdd/{change-name}/apply-progress` -> `mem_get` con el ID
6. query: `sdd/{change-name}/verify-report` -> `mem_get` con el ID

## Escritura a Memoria

Al finalizar, guarda el reporte de archivo con `mem_save`:
- **topic_key**: `sdd/{change-name}/archive-report`
- **type**: `architecture`
- **content**: resumen ejecutivo, decisiones clave, riesgos resueltos, follow-ups pendientes, lecciones aprendidas

Ademas, guarda el estado final del cambio:
- **topic_key**: `sdd/{change-name}/state`
- **type**: `decision`
- **content**: `status: archived`

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (reporte de archivo), `next_recommended` (ninguno), `risks` (follow-ups pendientes).
