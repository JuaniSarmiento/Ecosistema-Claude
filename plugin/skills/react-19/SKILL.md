---
name: react-19
description: React 19 patterns — Server Components by default, use(), Server Actions, useActionState, useOptimistic, no forwardRef.
---

## Component model

- **Server Components by default.** Add `'use client'` only when you need interactivity, browser APIs, or event listeners.
- Async Server Components fetch data directly — no useEffect, no useState for data:
  ```tsx
  async function UserProfile({ id }: { id: string }) {
    const user = await db.users.find(id); // runs on server
    return <div>{user.name}</div>;
  }
  ```

## `use()` hook

Read resources (promises, context) in render:
```tsx
const data = use(fetchUserPromise);
const theme = use(ThemeContext);
```

## Server Actions for mutations

```tsx
// actions.ts
'use server';
export async function createPost(formData: FormData) {
  await db.posts.create({ title: formData.get('title') });
  revalidatePath('/posts');
}
```

## `useActionState` for form state

```tsx
const [state, dispatch, isPending] = useActionState(createPost, null);

<form action={dispatch}>
  <input name="title" />
  <button disabled={isPending}>Save</button>
  {state?.error && <p>{state.error}</p>}
</form>
```

## `useOptimistic` for instant feedback

```tsx
const [optimisticItems, addOptimistic] = useOptimistic(items);

async function handleAdd(item: Item) {
  addOptimistic(item);          // instant
  await serverAction(item);     // reconciles
}
```

## ref as prop (no forwardRef)

```tsx
function Input({ ref, ...props }: InputProps & { ref?: Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}
```

## Document metadata in components

```tsx
function BlogPost({ title }: { title: string }) {
  return (
    <>
      <title>{title}</title>
      <meta name="description" content="..." />
      <article>...</article>
    </>
  );
}
```

## Stylesheet precedence

```tsx
<link rel="stylesheet" href="/critical.css" precedence="high" />
<link rel="stylesheet" href="/theme.css"    precedence="low"  />
```

## No useEffect for data fetching

Use Suspense + async Server Components or `use()` instead.
