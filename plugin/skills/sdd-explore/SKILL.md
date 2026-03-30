---
name: sdd-explore
description: Explora el estado actual del sistema antes de comprometer una solucion.
---

## Que Explorar

- Archivos relevantes
- Dependencias
- Constraints
- Comportamientos actuales
- Huecos de conocimiento
- Riesgos

No implementes todavia.

## Lectura de Dependencias

Esta fase no tiene dependencias previas. Es el punto de entrada del pipeline SDD.

## Deteccion de Backend de Memoria

Antes de cualquier operacion de persistencia, detecta que backend esta disponible:

1. Verifica si las herramientas de memoria (`mem_save`, `mem_search`) estan disponibles — pueden ser provistas por el MCP server `gentleman-memory` o `engram`. Ambos exponen la misma API.
2. Si alguna herramienta de memoria esta disponible -> usa modo `engram` (memoria persistente).
3. Si ninguna herramienta de memoria esta disponible -> usa modo `openspec` (archivos en disco).

## Escritura a Memoria

Al finalizar, guarda el resultado de la exploracion con `mem_save`:
- **topic_key**: `sdd/{change-name}/explore`
- **type**: `discovery`
- **content**: archivos relevantes, dependencias encontradas, constraints, riesgos identificados, preguntas abiertas

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (lista de hallazgos), `next_recommended` (propose), `risks`.
