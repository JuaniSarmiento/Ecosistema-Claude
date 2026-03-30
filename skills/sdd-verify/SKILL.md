---
name: sdd-verify
description: Verifica implementacion, pruebas y cumplimiento de criterios de aceptacion.
---

## Que Verificar

- Criterios de aceptacion
- Lint y tests relevantes
- Errores obvios
- Warnings criticos
- Riesgos restantes
- Deuda tecnica nueva

## Lectura de Dependencias

Lee spec Y tasks (AMBOS REQUERIDOS) con `mem_search`:
1. query: `sdd/{change-name}/spec` -> `mem_get` con el ID
2. query: `sdd/{change-name}/tasks` -> `mem_get` con el ID

Si falta alguna dependencia, DETENTE y reporta cual falta.

## Escritura a Memoria

Al finalizar, guarda el reporte de verificacion con `mem_save`:
- **topic_key**: `sdd/{change-name}/verify-report`
- **type**: `decision`
- **content**: veredicto (pass/fail/partial), criterios cumplidos, criterios fallidos, riesgos, deuda tecnica nueva

## Contrato de Resultado

Devuelve: `status`, `executive_summary`, `artifacts` (reporte de verificacion), `next_recommended` (archive si pass, apply si fail), `risks`.
