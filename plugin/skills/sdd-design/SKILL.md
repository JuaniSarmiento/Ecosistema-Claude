---
name: sdd-design
description: Disena la solucion tecnica antes de implementarla.
---

## Que Producir

- Arquitectura
- Cambios por modulo
- Interfaces
- Flujo de datos
- Validaciones
- Impacto en pruebas
- Rollback o mitigacion si aplica

## Lectura de Dependencias

Lee la proposal (REQUERIDA) con `mem_search`:
- query: `sdd/{change-name}/proposal`
- Usa `mem_get` con el ID para obtener contenido completo.

Si no hay proposal, DETENTE y reporta que falta la dependencia.

## Escritura a Memoria

Al finalizar, guarda el diseno con `mem_save`:
- **topic_key**: `sdd/{change-name}/design`
- **type**: `architecture`
- **content**: documento de diseno completo con todos los campos listados arriba

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (diseno completo), `next_recommended` (tasks), `risks`.
