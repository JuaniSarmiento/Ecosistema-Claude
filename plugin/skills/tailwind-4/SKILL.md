---
name: tailwind-4
description: TailwindCSS 4 patterns — CSS-first config, design tokens via @theme, utility-first with modern features.
---

# TailwindCSS 4

Tailwind 4 dropped the JS config. Everything is CSS now. If you're still writing `tailwind.config.js`, you're on the wrong version.

## Configuration

- **No more `tailwind.config.js`.** Configuration lives in CSS using `@theme`, `@variant`, and `@utility` directives.
- Import Tailwind in your main CSS file:
  ```css
  @import "tailwindcss";
  ```
- Define design tokens with `@theme`:
  ```css
  @theme {
    --color-brand: oklch(0.72 0.18 250);
    --color-surface: oklch(0.98 0.01 250);
    --font-sans: "Inter", sans-serif;
    --spacing-page: 2rem;
    --radius-card: 0.75rem;
  }
  ```
- Every token defined in `@theme` becomes a utility class automatically. `--color-brand` gives you `bg-brand`, `text-brand`, `border-brand`, etc.

## Color System

- Use `oklch()` for colors — it's perceptually uniform. Tailwind 4 uses it internally.
- Define color scales in `@theme`, not one-off values:
  ```css
  @theme {
    --color-primary-50: oklch(0.97 0.02 250);
    --color-primary-500: oklch(0.55 0.18 250);
    --color-primary-900: oklch(0.25 0.10 250);
  }
  ```
- Never use hex or rgb for new tokens. oklch gives you consistent perceived brightness across hues.

## Utility-First Rules

- **Prefer utility classes over `@apply`.** The whole point of Tailwind is avoiding CSS abstractions.
- `@apply` is acceptable ONLY for:
  - Base prose styles (`.prose h1`, `.prose p`)
  - Third-party component overrides where you can't add classes
  - Repeated patterns in more than 5 places that aren't worth extracting as components
- If you're using `@apply` more than 5 times in a file, you're doing it wrong — extract a component instead.

## Arbitrary Values

- **Never use arbitrary values when a token exists.** `p-[16px]` is wrong when `p-4` exists.
- If you need a value often, add it to `@theme`. Arbitrary values are for true one-offs.
- Arbitrary properties: `[clip-path:circle(50%)]` — acceptable when no utility exists.

## Responsive Design

- **Mobile-first, always.** Base styles are mobile. Add breakpoints to go up:
  ```html
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
  ```
- Never write `sm:` to undo a desktop style. If you need that, your base styles are wrong.
- Use container queries for component-level responsiveness:
  ```html
  <div class="@container">
    <div class="@sm:flex @md:grid @md:grid-cols-2">
  ```
- Container queries (`@container`) replace media queries for components that need to adapt to their parent, not the viewport.

## Dark Mode

- Prefer `prefers-color-scheme` (automatic) unless the app needs a manual toggle.
- For manual toggle, use the `class` strategy with a `dark` class on `<html>`.
- Define dark mode tokens in `@theme` or use the `dark:` variant:
  ```html
  <div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
  ```
- Don't duplicate entire component styles for dark mode — use CSS variables so the switch is at the token level.

## Custom Utilities and Variants

- Create custom utilities with `@utility`:
  ```css
  @utility scrollbar-hidden {
    scrollbar-width: none;
    &::-webkit-scrollbar { display: none; }
  }
  ```
- Create custom variants with `@variant`:
  ```css
  @variant hocus (&:hover, &:focus-visible);
  ```

## Performance

- Tailwind 4 uses Oxide engine — it's fast. Don't worry about purging; it's automatic.
- Keep your `@theme` focused. Don't define 200 tokens you'll never use.
- Use `@layer` to control specificity if you mix Tailwind with custom CSS.

## Anti-Patterns

- DO NOT use `@apply` to recreate Bootstrap-style `.btn-primary` classes. Make a component.
- DO NOT nest Tailwind utilities in CSS — that defeats the purpose.
- DO NOT use `!important` via `!` prefix unless overriding third-party CSS.
- DO NOT mix Tailwind with another CSS framework. Pick one.
- DO NOT use inline styles when a Tailwind utility exists.
