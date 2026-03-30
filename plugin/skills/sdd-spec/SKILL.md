---
name: sdd-spec
description: Redacta una especificacion funcional y tecnica con criterios de aceptacion verificables.
---

## Que Producir

- Objetivo
- Alcance
- Fuera de alcance
- Criterios de aceptacion
- Casos borde
- Dependencias
- Riesgos
- Preguntas abiertas

## Deteccion de Backend de Memoria

Antes de cualquier operacion de persistencia, detecta que backend esta disponible:

1. Verifica si las herramientas de memoria (`mem_save`, `mem_search`) estan disponibles — pueden ser provistas por el MCP server `gentleman-memory` o `engram`. Ambos exponen la misma API.
2. Si alguna herramienta de memoria esta disponible -> usa modo `engram` (memoria persistente).
3. Si ninguna herramienta de memoria esta disponible -> usa modo `openspec` (archivos en disco).

## Lectura de Dependencias

Lee la proposal (REQUERIDA) con `mem_search`:
- query: `sdd/{change-name}/proposal`
- Usa `mem_get` con el ID para obtener contenido completo.

Si no hay proposal, DETENTE y reporta que falta la dependencia.

## Escritura a Memoria

Al finalizar, guarda la spec con `mem_save`:
- **topic_key**: `sdd/{change-name}/spec`
- **type**: `architecture`
- **content**: especificacion completa con todos los campos listados arriba

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (spec completa), `next_recommended` (design si falta, o tasks), `risks`.
