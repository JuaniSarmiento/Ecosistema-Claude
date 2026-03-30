---
name: prisma-drizzle
description: Database ORM patterns for Prisma and Drizzle — schema-first, N+1 prevention, transactions, indexing.
---

# Prisma & Drizzle ORM

Your ORM is not a magic wand. It generates SQL. If you don't understand the SQL it produces, you'll write slow code without knowing why.

## Schema as Source of Truth

- The schema file IS the database documentation. Keep it clean.
- **Migrations are generated FROM the schema.** Never edit migration files manually.
- Prisma: `npx prisma migrate dev` for development, `npx prisma migrate deploy` for production.
- Drizzle: `npx drizzle-kit generate` then `npx drizzle-kit migrate`.
- Every schema change goes through a migration. No exceptions.

## Relations

- **Define relations on BOTH sides** for full type safety:
  ```prisma
  // Prisma
  model User {
    id    String  @id @default(cuid())
    posts Post[]
  }
  model Post {
    id       String @id @default(cuid())
    author   User   @relation(fields: [authorId], references: [id])
    authorId String
  }
  ```
  ```ts
  // Drizzle
  export const users = pgTable('users', {
    id: text('id').primaryKey().$defaultFn(() => createId()),
  });
  export const posts = pgTable('posts', {
    id: text('id').primaryKey().$defaultFn(() => createId()),
    authorId: text('author_id').notNull().references(() => users.id),
  });
  export const usersRelations = relations(users, ({ many }) => ({ posts: many(posts) }));
  export const postsRelations = relations(posts, ({ one }) => ({
    author: one(users, { fields: [posts.authorId], references: [users.id] }),
  }));
  ```

## Query Only What You Need

- **Never select all columns** when you only need a few:
  ```ts
  // Prisma
  const users = await prisma.user.findMany({ select: { id: true, name: true, email: true } });

  // Drizzle
  const users = await db.select({ id: users.id, name: users.name }).from(users);
  ```
- Selecting everything wastes bandwidth and memory, especially with large text/blob columns.

## The N+1 Problem

This is the most common ORM performance killer. Learn to recognize it.

- **BAD — N+1 queries:**
  ```ts
  const users = await prisma.user.findMany();
  for (const user of users) {
    const posts = await prisma.post.findMany({ where: { authorId: user.id } });
  }
  ```
- **GOOD — eager loading:**
  ```ts
  // Prisma
  const users = await prisma.user.findMany({ include: { posts: true } });

  // Drizzle
  const result = await db.query.users.findMany({ with: { posts: true } });
  ```
- Rule: if you're querying inside a loop, you have an N+1. Fix it with `include`, `with`, or a join.

## Transactions

- **Multi-table writes MUST be in a transaction:**
  ```ts
  // Prisma
  await prisma.$transaction([
    prisma.order.create({ data: orderData }),
    prisma.inventory.update({ where: { id: itemId }, data: { stock: { decrement: 1 } } }),
  ]);

  // Drizzle
  await db.transaction(async (tx) => {
    await tx.insert(orders).values(orderData);
    await tx.update(inventory).set({ stock: sql`stock - 1` }).where(eq(inventory.id, itemId));
  });
  ```
- If one operation fails, all roll back. That's the whole point.
- Keep transactions short — don't put API calls or slow operations inside them.

## Indexes

- **Index columns used in WHERE, ORDER BY, and JOIN:**
  ```prisma
  model Post {
    id        String   @id @default(cuid())
    authorId  String
    status    String
    createdAt DateTime @default(now())

    @@index([authorId])
    @@index([status, createdAt])
  }
  ```
- Compound indexes: the ORDER of columns matters. Put high-selectivity columns first.
- Don't index everything — indexes slow down writes. Index what you query.
- If a query is slow, check `EXPLAIN ANALYZE` before blindly adding indexes.

## Soft Deletes

- Add `deletedAt` column instead of actually deleting:
  ```prisma
  model User {
    id        String    @id @default(cuid())
    deletedAt DateTime?
  }
  ```
- **Filter soft-deleted records in EVERY query.** Use middleware or a base query scope.
- Prisma middleware example:
  ```ts
  prisma.$use(async (params, next) => {
    if (params.action === 'findMany') {
      params.args.where = { ...params.args.where, deletedAt: null };
    }
    return next(params);
  });
  ```

## Connection Pooling

- **Production MUST have connection pooling.** One connection per request kills your DB.
- Prisma: use built-in pool (`connection_limit` in URL) or PgBouncer.
- Drizzle: configure pool in your driver (e.g., `node-postgres` pool settings).
- Serverless: use connection poolers (Neon pooler, Supabase pgbouncer, PrismaAccelerate).

## Seed Scripts

- Every project needs a seed script for development data. Use realistic but obviously fake data.
- Seed scripts are idempotent — running twice doesn't duplicate data. Use upsert or check existence.

## Anti-Patterns

- DO NOT write raw SQL unless the ORM genuinely can't express the query.
- DO NOT query inside loops — that's always an N+1.
- DO NOT skip migrations — manual DB changes will drift from schema.
- DO NOT store business logic in the database (triggers, stored procedures) unless there's a strong reason.
- DO NOT use `findFirst` without `orderBy` when you expect a specific record — results are non-deterministic.
- DO NOT ignore slow query logs. If a query takes >100ms, investigate.
