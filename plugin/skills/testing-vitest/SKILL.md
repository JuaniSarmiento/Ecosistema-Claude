---
name: testing-vitest
description: Vitest testing patterns — behavior-driven, AAA structure, smart mocking, testing-library best practices.
---

# Vitest Testing

Tests exist to catch regressions and document behavior. If your test breaks when you refactor an implementation detail, it's a bad test.

## Structure

- Every test file follows **Arrange-Act-Assert**:
  ```ts
  it('applies discount when coupon is valid', () => {
    // Arrange
    const cart = createCart([{ id: '1', price: 100 }]);
    const coupon = { code: 'SAVE20', discount: 0.2 };

    // Act
    const result = applyCoupon(cart, coupon);

    // Assert
    expect(result.total).toBe(80);
  });
  ```
- One assertion per test when possible. Multiple assertions are OK if they verify the SAME behavior.

## Naming

- `describe` blocks name the unit: `describe('applyCoupon', ...)`.
- `it` blocks describe WHAT happens, not HOW: `it('returns discounted total for valid coupon')`.
- Never: `it('should call calculateDiscount and return')` — that's testing implementation.
- Read the test name as a sentence: `applyCoupon → returns discounted total for valid coupon`.

## Test Behavior, Not Implementation

- Test the public API. If a function returns the right result, you don't care which internal helper it called.
- If refactoring internals breaks your test, the test is coupled to implementation — rewrite it.
- Test WHAT the code does, not HOW it does it.

## Mocking

### When to Mock
- **Mock external boundaries**: API calls, database, file system, third-party services.
- **Never mock internal modules.** If `calculateTotal` calls `applyTax`, don't mock `applyTax` — test the real thing.
- The more you mock, the less your tests prove. Mock at the edges, test everything in between.

### How to Mock
- `vi.fn()` for spies and stubs:
  ```ts
  const onSubmit = vi.fn();
  render(<Form onSubmit={onSubmit} />);
  await userEvent.click(screen.getByRole('button', { name: /submit/i }));
  expect(onSubmit).toHaveBeenCalledWith({ email: 'test@example.com' });
  ```
- `vi.mock()` for module-level mocks:
  ```ts
  vi.mock('@/lib/api', () => ({
    fetchUsers: vi.fn().mockResolvedValue([{ id: 1, name: 'Ada' }]),
  }));
  ```
- Always reset mocks between tests: use `beforeEach(() => vi.clearAllMocks())`.

## Testing Library (DOM / React)

### Query Priority (STRICT)
1. `getByRole` — always first. Accessible, semantic.
2. `getByLabelText` — for form elements.
3. `getByPlaceholderText` — acceptable fallback for inputs.
4. `getByText` — for non-interactive text content.
5. `getByTestId` — LAST RESORT only. If you need this, your HTML probably lacks semantics.

### User Events
- Use `@testing-library/user-event` over `fireEvent`. It simulates real user behavior:
  ```ts
  import userEvent from '@testing-library/user-event';
  const user = userEvent.setup();
  await user.click(button);
  await user.type(input, 'hello');
  ```

### Async
- Use `findBy*` for elements that appear after async operations — it waits automatically.
- Use `waitFor` when you need to assert a condition that settles asynchronously:
  ```ts
  await waitFor(() => {
    expect(screen.getByText('Success')).toBeInTheDocument();
  });
  ```
- **NEVER use `setTimeout`, `sleep`, or fixed delays in tests.** If you need to wait, use `waitFor` or `findBy*`.

## Snapshot Tests

- Use snapshots ONLY for serializable output: API responses, config objects, CLI output.
- **NEVER snapshot React components.** They break on every styling change and tell you nothing useful.
- If you use snapshots, keep them small and review diffs carefully. Large snapshots become rubber-stamp approvals.

## Coverage

- Coverage is a signal, not a target. 100% coverage with bad tests is worse than 70% with good ones.
- Focus on:
  - Edge cases (empty arrays, null values, boundary conditions)
  - Error paths (what happens when the API fails?)
  - Business logic (the stuff that actually matters)
- Don't write tests just to hit a coverage number.

## Test Organization

- Co-locate tests with source: `cart.ts` → `cart.test.ts` in the same directory.
- Integration tests go in `__tests__/` or `tests/` at the module level.
- E2E tests are separate — don't mix them with unit/integration tests.

## Configuration

- Vitest config in `vitest.config.ts` or inline in `vite.config.ts`:
  ```ts
  export default defineConfig({
    test: {
      globals: true,
      environment: 'jsdom', // or 'happy-dom' for speed
      setupFiles: ['./tests/setup.ts'],
      coverage: { provider: 'v8', reporter: ['text', 'html'] },
    },
  });
  ```
- Setup file for testing-library:
  ```ts
  import '@testing-library/jest-dom/vitest';
  ```

## Anti-Patterns

- DO NOT test implementation details (internal function calls, state shape, private methods).
- DO NOT write tests that pass regardless of the code (always-true assertions).
- DO NOT mock everything — that's testing your mocks, not your code.
- DO NOT ignore flaky tests — fix them or delete them. Flaky tests erode trust.
- DO NOT couple test setup to other tests. Each test must be independent.
