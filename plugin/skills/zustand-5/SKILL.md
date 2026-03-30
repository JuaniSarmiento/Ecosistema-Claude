---
name: zustand-5
description: Zustand 5 state management — minimal stores, slices, selectors, middleware done right.
---

# Zustand 5

Zustand is intentionally simple. Don't make it complex. If your store looks like Redux, you've gone too far.

## Store Design

- **One store per domain.** `useAuthStore`, `useCartStore`, `useUIStore`. NOT one giant `useAppStore`.
- A store owns a slice of your app's state. If two stores need to talk, they do it through actions, not shared state.
- Keep stores small. If a store has more than 10 state properties, break it into slices or separate stores.

## Creating Stores

- Basic store with Zustand 5:
  ```ts
  import { create } from 'zustand';

  interface CartStore {
    items: CartItem[];
    addItem: (item: CartItem) => void;
    removeItem: (id: string) => void;
    total: () => number;
  }

  const useCartStore = create<CartStore>((set, get) => ({
    items: [],
    addItem: (item) => set((s) => ({ items: [...s.items, item] })),
    removeItem: (id) => set((s) => ({ items: s.items.filter(i => i.id !== id) })),
    total: () => get().items.reduce((sum, i) => sum + i.price, 0),
  }));
  ```
- **Colocate state and actions.** Actions live inside the store, not in separate files or hooks.
- Never define actions outside the store and import them. The store is the single source of truth.

## Selectors (Performance Critical)

- **Always use selectors.** Without them, every component re-renders on any store change.
  ```ts
  // BAD — re-renders on ANY state change
  const { items } = useCartStore();

  // GOOD — re-renders only when items changes
  const items = useCartStore((s) => s.items);
  ```
- For derived data, create selector functions:
  ```ts
  const selectItemCount = (s: CartStore) => s.items.length;
  const count = useCartStore(selectItemCount);
  ```
- For multiple values, use `useShallow` to avoid unnecessary re-renders:
  ```ts
  import { useShallow } from 'zustand/shallow';
  const { items, total } = useCartStore(useShallow((s) => ({ items: s.items, total: s.total })));
  ```

## Slices Pattern

- For complex stores, use slices to keep code organized:
  ```ts
  const createItemsSlice = (set, get) => ({
    items: [],
    addItem: (item) => set((s) => ({ items: [...s.items, item] })),
  });

  const createDiscountSlice = (set, get) => ({
    discount: 0,
    applyDiscount: (pct) => set({ discount: pct }),
  });

  const useStore = create((...a) => ({
    ...createItemsSlice(...a),
    ...createDiscountSlice(...a),
  }));
  ```
- Each slice is a plain function — easy to test in isolation.

## Middleware

### Immer
- Use `immer` middleware ONLY when state is deeply nested (3+ levels).
- For flat state, spread operator is simpler and more explicit.
  ```ts
  import { immer } from 'zustand/middleware/immer';
  const useStore = create(immer((set) => ({
    nested: { deep: { value: 0 } },
    update: () => set((s) => { s.nested.deep.value = 1; }),
  })));
  ```

### Persist
- Use `persist` for state that should survive page reloads (cart, preferences, auth tokens):
  ```ts
  import { persist } from 'zustand/middleware';
  const useStore = create(persist(
    (set) => ({ theme: 'light', setTheme: (t) => set({ theme: t }) }),
    { name: 'ui-storage' }
  ));
  ```
- Use `partialize` to persist only specific fields — never persist the entire store blindly.

### Devtools
- Enable in development only:
  ```ts
  import { devtools } from 'zustand/middleware';
  const useStore = create(
    devtools((set) => ({ ... }), { enabled: process.env.NODE_ENV === 'development' })
  );
  ```

## Side Effects

- Use `subscribe` for side effects, NOT `useEffect`:
  ```ts
  useCartStore.subscribe(
    (s) => s.items,
    (items) => analytics.track('cart_updated', { count: items.length }),
    { equalityFn: shallow }
  );
  ```
- `subscribe` runs outside React — no component coupling, no re-render issues.

## Testing

- Stores are plain functions — test them without React:
  ```ts
  it('adds item to cart', () => {
    const store = useCartStore.getState();
    useCartStore.getState().addItem({ id: '1', price: 10 });
    expect(useCartStore.getState().items).toHaveLength(1);
  });
  ```
- Reset store between tests with `useStore.setState(initialState)`.

## Anti-Patterns

- DO NOT use `useEffect` to sync Zustand state — use `subscribe`.
- DO NOT destructure the entire store without selectors.
- DO NOT put API calls in components — put them in store actions.
- DO NOT create stores inside components. Stores are module-level singletons.
- DO NOT use Zustand for server state — use TanStack Query or SWR for that.
