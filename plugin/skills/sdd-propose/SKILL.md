---
name: sdd-propose
description: Propone enfoques alternativos y justifica la eleccion recomendada.
---

## Que Producir

- Listar opciones razonables
- Explicar ventajas y costos de cada una
- Elegir una recomendacion
- Dejar claro por que se descartan las otras

## Deteccion de Backend de Memoria

Antes de cualquier operacion de persistencia, detecta que backend esta disponible:

1. Verifica si las herramientas de memoria (`mem_save`, `mem_search`) estan disponibles — pueden ser provistas por el MCP server `gentleman-memory` o `engram`. Ambos exponen la misma API.
2. Si alguna herramienta de memoria esta disponible -> usa modo `engram` (memoria persistente).
3. Si ninguna herramienta de memoria esta disponible -> usa modo `openspec` (archivos en disco).

## Lectura de Dependencias

Busca la exploracion previa (opcional) con `mem_search`:
- query: `sdd/{change-name}/explore`
- Si encuentra resultado, usa `mem_get` con el ID para obtener contenido completo.

## Escritura a Memoria

Al finalizar, guarda la propuesta con `mem_save`:
- **topic_key**: `sdd/{change-name}/proposal`
- **type**: `decision`
- **content**: opciones evaluadas, recomendacion elegida, justificacion, trade-offs

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (propuesta completa), `next_recommended` (spec + design), `risks`.
