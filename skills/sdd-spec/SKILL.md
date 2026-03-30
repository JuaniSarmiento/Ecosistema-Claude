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
