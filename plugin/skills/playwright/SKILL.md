---
name: playwright
description: Diseña pruebas E2E legibles, estables y centradas en comportamiento observable.
---

## Selectores (sin CSS selectors)
- `page.getByRole()` — accesibilidad primero (button, link, heading, etc)
- `page.getByText()` — por contenido visible
- `page.getByTestId()` — si nada más funciona, usa `data-testid`

## Estructura
- `test.describe()` para agrupar relacionadas
- `test.beforeEach()` para setup, `afterEach()` para cleanup
- Page Object Model para flujos complejos (login, checkout, etc)
- Tests independientes — ejecutan en paralelo por defecto

## Assertions
- `expect(locator).toBeVisible()` — observable, no timeouts
- `await expect(page).toHaveURL()` — validar navegación
- `expect(page).toHaveScreenshot()` — visual regression
- NO `page.waitForTimeout()` — esperá condiciones, no tiempo

## Mocking
- `page.route()` para interceptar APIs
- `test.use({ storageState })` para reutilizar auth
- `test.use({ ...devices['iPhone 14'] })` para mobile testing

## Debug
- `npx playwright show-trace trace.zip`
- Network tab en DevTools para ver requests
- Traces automáticas si falla un test
