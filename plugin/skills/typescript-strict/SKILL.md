---
name: typescript-strict
description: TypeScript strict mode patterns — branded types, discriminated unions, runtime validation, no any, no enums.
---

## tsconfig requirements

```json
{
  "strict": true,
  "noUncheckedIndexedAccess": true,
  "exactOptionalPropertyTypes": true
}
```

## Core rules

- `unknown` over `any`. Narrow with type guards before use.
- No enums — use `as const` objects:
  ```ts
  const Role = { Admin: 'admin', User: 'user' } as const;
  type Role = typeof Role[keyof typeof Role];
  ```
- Discriminated unions over type assertions:
  ```ts
  type Result<T> = { ok: true; data: T } | { ok: false; error: string };
  ```
- `satisfies` for type-checking without widening:
  ```ts
  const config = { port: 3000, host: 'localhost' } satisfies ServerConfig;
  ```

## Branded types for domain primitives

```ts
type UserId = string & { readonly __brand: 'UserId' };
type Email  = string & { readonly __brand: 'Email'  };

const toUserId = (id: string): UserId => id as UserId;
```

## Template literal types for string patterns

```ts
type EventName = `on${Capitalize<string>}`;
type CssVar    = `--${string}`;
```

## Explicit return types on all exported functions

```ts
export function parseUser(raw: unknown): User { ... }
```

## Zod at system boundaries

```ts
const UserSchema = z.object({ id: z.string(), email: z.string().email() });
type User = z.infer<typeof UserSchema>;

// At API boundary:
const user = UserSchema.parse(req.body);
```

## Type guards

```ts
function isError(val: unknown): val is Error {
  return val instanceof Error;
}
```
