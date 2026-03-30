---
name: nextjs-15
description: Next.js 15 patterns — App Router, async request APIs, Server Actions, Turbopack, route handlers, static generation.
---

## App Router only

No `pages/` directory. All routes live under `app/`.

## Async request APIs (breaking change in 15)

`cookies()`, `headers()`, `params`, and `searchParams` are all async now:

```ts
// app/users/[id]/page.tsx
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const cookieStore = await cookies();
  const headersList = await headers();
}
```

## Dynamic rendering opt-in

```ts
import { connection } from 'next/server';

export default async function Page() {
  await connection(); // opts into dynamic rendering
  ...
}
```

## Turbopack (default dev bundler)

```bash
next dev   # uses Turbopack by default in 15
next dev --turbopack  # explicit
```

## Server Actions in separate files

```ts
// app/actions/posts.ts
'use server';

export async function deletePost(id: string) {
  await db.posts.delete(id);
  revalidatePath('/posts');
}
```

## Route handlers

```ts
// app/api/users/route.ts
export async function GET(request: Request) {
  const users = await db.users.findAll();
  return Response.json(users);
}
```

## Parallel & intercepting routes

```
app/
  @modal/   ← parallel slot
  (.)photo/ ← intercepting route (same level)
```

## Static generation

```ts
export async function generateStaticParams() {
  const posts = await db.posts.findAll();
  return posts.map(p => ({ slug: p.slug }));
}
```

## next/image

```tsx
import Image from 'next/image';
// Always provide width + height or use fill
<Image src="/hero.jpg" alt="Hero" width={800} height={600} />
```

## Metadata API

```ts
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPost(slug);
  return { title: post.title, description: post.excerpt };
}
```
