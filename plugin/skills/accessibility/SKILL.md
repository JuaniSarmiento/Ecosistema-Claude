---
name: accessibility
description: Web accessibility (a11y) — semantic HTML, ARIA, keyboard navigation, color contrast, screen reader support.
---

# Web Accessibility (a11y)

Accessibility is not a feature you add later. It's a quality of well-written HTML. If your markup is semantic, you're already 80% there.

## Semantic HTML First

- **Use the right element for the job.** The browser gives you behavior for free:
  | Instead of... | Use... | Why |
  |--------------|--------|-----|
  | `<div onClick>` | `<button>` | Keyboard support, focus, screen reader announce |
  | `<div class="nav">` | `<nav>` | Screen readers identify navigation |
  | `<div class="header">` | `<header>` | Landmark for assistive tech |
  | `<span class="link">` | `<a href>` | Keyboard navigable, right-click menu |
  | `<div class="list">` | `<ul>/<ol>` | Screen readers announce item count |
- A `<div>` with `onClick` is NOT a button. It has no keyboard support, no focus indicator, no screen reader announcement. You'd need `role="button"`, `tabIndex`, `onKeyDown` — or just use `<button>`.

## ARIA — When HTML Isn't Enough

- **First rule of ARIA: don't use ARIA if semantic HTML works.** ARIA supplements, it doesn't replace.
- Essential ARIA attributes:
  | Attribute | When |
  |-----------|------|
  | `aria-label` | Element has no visible text (icon button, close X) |
  | `aria-labelledby` | Label is another element on the page |
  | `aria-describedby` | Additional context beyond the label |
  | `aria-hidden="true"` | Decorative content invisible to screen readers |
  | `aria-live="polite"` | Dynamic content updates (toasts, loading states) |
  | `aria-expanded` | Collapsible sections, dropdowns |
  | `role` | Only when the element's native role is wrong |
- **Common mistake:** adding `role="button"` to a `<button>`. It already has that role.

## Keyboard Navigation

- **Every interactive element MUST be reachable via keyboard.**
- Tab order follows DOM order. If your tab order is weird, fix the DOM, don't use `tabIndex > 0`.
- `tabIndex` values:
  | Value | Meaning |
  |-------|---------|
  | `0` | Element is focusable in natural tab order |
  | `-1` | Focusable programmatically but not via tab |
  | `> 0` | NEVER USE — forces arbitrary tab order |
- Keyboard patterns:
  - `Enter`/`Space` activates buttons and links.
  - `Escape` closes modals, dropdowns, dialogs.
  - Arrow keys navigate within components (tabs, menus, radio groups).
  - Focus trap in modals — tab should cycle within the modal, not escape to the page behind.
  - Restore focus to the trigger element when modal closes.

## Focus Management

- **Visible focus indicators are mandatory.** Never remove `:focus` without providing `:focus-visible`:
  ```css
  :focus-visible {
    outline: 2px solid var(--color-primary);
    outline-offset: 2px;
  }
  ```
- Skip navigation link — first focusable element should let keyboard users skip the nav:
  ```html
  <a href="#main-content" class="sr-only focus:not-sr-only">Skip to content</a>
  ```
- `sr-only` class (visually hidden but accessible):
  ```css
  .sr-only {
    position: absolute;
    width: 1px; height: 1px;
    padding: 0; margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }
  ```

## Color and Contrast

- **Minimum contrast ratios** (WCAG 2.1 AA):
  - Normal text: 4.5:1
  - Large text (18px bold or 24px regular): 3:1
  - UI components and graphical objects: 3:1
- **Never convey information through color alone.** Add icons, text, or patterns.
  - Bad: red border for error fields.
  - Good: red border + error icon + error text.
- Test with browser devtools contrast checker or tools like Stark.

## Images

- **Content images:** descriptive alt text explaining what the image shows:
  ```html
  <img src="team.jpg" alt="Team celebrating product launch at the office" />
  ```
- **Decorative images:** empty alt to hide from screen readers:
  ```html
  <img src="divider.svg" alt="" />
  ```
- **Never use "image of..." or "photo of..."** in alt text — screen readers already announce it as an image.

## Forms

- **Every input needs a label.** No exceptions:
  ```html
  <label for="email">Email address</label>
  <input id="email" type="email" required />
  ```
- Placeholder is NOT a label. It disappears on focus and has insufficient contrast.
- Group related fields with `<fieldset>` and `<legend>`.
- Error messages: associate with `aria-describedby`:
  ```html
  <input id="email" aria-describedby="email-error" aria-invalid="true" />
  <span id="email-error" role="alert">Email format is invalid</span>
  ```

## Motion and Animation

- Respect `prefers-reduced-motion`:
  ```css
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: 0.01ms !important;
      transition-duration: 0.01ms !important;
    }
  }
  ```
- No auto-playing animations that can't be paused.
- No flashing content (3 flashes per second threshold).

## Testing

- **Automated tools catch ~30% of issues.** axe-core, Lighthouse, eslint-plugin-jsx-a11y.
- **Manual testing is mandatory:**
  - Navigate entirely with keyboard. Can you reach everything? Is the order logical?
  - Test with a screen reader: NVDA (Windows), VoiceOver (macOS/iOS), TalkBack (Android).
  - Zoom to 200% — does the layout break?
  - Disable CSS — does the content still make sense in reading order?

## Anti-Patterns

- DO NOT remove focus outlines without a visible replacement.
- DO NOT use `tabIndex > 0`. Ever.
- DO NOT rely on color alone to convey state (error, success, active).
- DO NOT use `aria-label` when visible text already serves as a label.
- DO NOT hide content from screen readers that sighted users can see (unless truly decorative).
- DO NOT use `<div>` or `<span>` as interactive elements. Use `<button>`, `<a>`, `<input>`.
- DO NOT skip heading levels — go `h1 → h2 → h3`, not `h1 → h3`.
