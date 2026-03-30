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

## Memoria

Al finalizar, guarda el contexto del proyecto con `mem_save`:
- **topic_key**: `sdd-init/{project}`
- **type**: `architecture`
- **content**: tipo de cambio, objetivo, alcance, secuencia SDD propuesta
