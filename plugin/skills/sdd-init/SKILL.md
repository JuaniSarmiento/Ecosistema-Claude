---
name: sdd-init
description: Inicializa un cambio sustancial y define el tipo de trabajo antes de explorar o implementar.
---

Usa esta skill cuando el trabajo sea mayor que un cambio trivial.

## Pasos

1. Clasificar el tipo de cambio (feature, refactor, bugfix, migration, etc.).
2. Determinar si requiere exploracion, especificacion o diseno.
3. Definir el objetivo principal.
4. Delimitar alcance inicial.
5. Proponer la secuencia SDD adecuada.

## Deteccion de Backend de Memoria

Antes de cualquier operacion de persistencia, detecta que backend esta disponible:

1. Verifica si las herramientas de memoria (`mem_save`, `mem_search`) estan disponibles — pueden ser provistas por el MCP server `gentleman-memory` o `engram`. Ambos exponen la misma API.
2. Si alguna herramienta de memoria esta disponible -> usa modo `engram` (memoria persistente). No importa cual MCP server la provee.
3. Si ninguna herramienta de memoria esta disponible -> usa modo `openspec` (archivos en disco).

Reporta que backend se detecto en el resumen final (ej: "Persistence: memory (gentleman-memory)" o "Persistence: memory (engram)" o "Persistence: openspec").

## Memoria

Al finalizar, guarda el contexto del proyecto con `mem_save`:
- **topic_key**: `sdd-init/{project}`
- **type**: `architecture`
- **content**: tipo de cambio, objetivo, alcance, secuencia SDD propuesta
