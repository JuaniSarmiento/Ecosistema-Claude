---
name: sdd-tasks
description: Divide la implementacion en tareas pequenas, ordenadas y verificables.
---

## Que Producir

Divide el trabajo en tareas:
- Atomicas
- Secuenciales o paralelizables
- Con criterio de finalizacion
- Con archivos implicados

## Lectura de Dependencias

Lee spec Y design (AMBOS REQUERIDOS) con `mem_search`:
1. query: `sdd/{change-name}/spec` -> `mem_get` con el ID
2. query: `sdd/{change-name}/design` -> `mem_get` con el ID

Si falta alguna dependencia, DETENTE y reporta cual falta.

## Escritura a Memoria

Al finalizar, guarda el task breakdown con `mem_save`:
- **topic_key**: `sdd/{change-name}/tasks`
- **type**: `architecture`
- **content**: lista ordenada de tareas con dependencias, archivos, y criterios de finalizacion

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (lista de tareas), `next_recommended` (apply), `risks`.
