---
name: pr-review
description: Ejecuta una revisión previa a cierre o PR con foco en aceptación, calidad, riesgo y mantenibilidad.
---

## Pre-revisión
- Relee el objetivo y los **criterios de aceptación** completamente
- Repasa el contexto: ¿qué problema resuelve esto?

## Revisión por módulo
- Diff completo módulo por módulo, NO archivo por archivo
- Breaking changes, migrations, cambios en API contracts
- Impacto en dependencias (qué else se rompe?)

## Checklist técnico
- **Seguridad**: secrets expuestos, inyección, bypasses de auth
- **Performance**: N+1 queries, renders innecesarios, índices faltantes
- **Pruebas**: nueva lógica cubierta, edge cases testeados, NO solo snapshots
- **Convenciones**: naming, estructura, imports ordenados según proyecto

## Cada finding
```
severity: critical | warning | suggestion
file:line: exact location
explanation: por qué es un problema
```

## Veredicto
- APPROVED — listo, sin observaciones
- APPROVED_WITH_FOLLOWUPS — listo ahora, seguimiento después
- CHANGES_REQUESTED — bloqueado hasta fixes

## Follow-ups
Sección separada con tickets/issues para después del merge