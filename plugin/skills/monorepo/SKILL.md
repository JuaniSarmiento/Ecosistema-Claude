---
name: monorepo
description: Monorepo patterns with Turborepo and pnpm workspaces — shared packages, pipeline config, caching.
---

# Monorepo (Turborepo + pnpm)

A monorepo is not "all code in one folder." It's a dependency graph with clear boundaries. If your packages depend on each other in unpredictable ways, you don't have a monorepo — you have a monolith.

## Project Structure

```
root/
├── apps/
│   ├── web/            # Next.js frontend
│   ├── api/            # Express/Fastify backend
│   └── mobile/         # React Native
├── packages/
│   ├── ui/             # Shared component library
│   ├── config/         # Shared tsconfig, eslint, prettier
│   ├── utils/          # Shared utility functions
│   └── types/          # Shared TypeScript types
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

- `apps/` — deployable applications. Each has its own build, deploy, and runtime.
- `packages/` — shared libraries consumed by apps. Not deployed independently.

## pnpm Workspaces

- Define workspaces in `pnpm-workspace.yaml`:
  ```yaml
  packages:
    - "apps/*"
    - "packages/*"
  ```
- Internal packages use `workspace:*` for versioning:
  ```json
  {
    "dependencies": {
      "@repo/ui": "workspace:*",
      "@repo/utils": "workspace:*"
    }
  }
  ```
- `workspace:*` resolves to the local package. pnpm replaces it with the actual version on publish.

## Dependency Management

- **Shared deps go in the root `package.json`:** TypeScript, ESLint, Prettier, Turbo.
- **App-specific deps go in their own `package.json`:** Next.js in `apps/web`, Express in `apps/api`.
- **Never duplicate shared deps across packages.** If `react` is in root, don't add it to each app.
- Run `pnpm install` from root. Always.
- Use `pnpm --filter <package> add <dep>` to add deps to specific packages.

## Shared Packages

### Package Exports
- Every shared package needs proper `exports` in `package.json`:
  ```json
  {
    "name": "@repo/ui",
    "exports": {
      ".": "./src/index.ts",
      "./button": "./src/button.tsx",
      "./card": "./src/card.tsx"
    }
  }
  ```
- Use granular exports so apps can import only what they need.
- Internal packages can export raw TypeScript — the consuming app handles compilation.

### Shared Config
- Shared `tsconfig.base.json` in `packages/config/`:
  ```json
  {
    "compilerOptions": {
      "strict": true,
      "target": "ES2022",
      "module": "ESNext",
      "moduleResolution": "bundler",
      "paths": { "@repo/*": ["../../packages/*/src"] }
    }
  }
  ```
- Each app extends the shared config:
  ```json
  { "extends": "@repo/config/tsconfig.base.json" }
  ```

## Turborepo Configuration

- `turbo.json` defines the build pipeline:
  ```json
  {
    "$schema": "https://turbo.build/schema.json",
    "tasks": {
      "build": {
        "dependsOn": ["^build"],
        "outputs": ["dist/**", ".next/**"]
      },
      "dev": {
        "cache": false,
        "persistent": true
      },
      "lint": {
        "dependsOn": ["^build"]
      },
      "test": {
        "dependsOn": ["^build"]
      }
    }
  }
  ```
- `^build` means "build my dependencies first." This ensures packages are built before apps that consume them.
- `outputs` tells Turbo what to cache. Be explicit.

## Caching

- **Local caching** — enabled by default. Turbo hashes inputs and skips tasks whose output is cached.
- **Remote caching** — essential for CI. Cache is shared across all CI runs:
  ```bash
  npx turbo login
  npx turbo link
  ```
- Use Vercel Remote Cache or self-hosted (Turborepo supports custom endpoints).
- Cache hit = instant build. This is the main performance win of Turborepo.

## Running Tasks

- `pnpm turbo build` — build everything in dependency order.
- `pnpm turbo lint --filter=apps/web` — target specific packages with `--filter`.
- `turbo dev` runs all dev scripts in parallel with proper dependency ordering.
- Each package has its own `tsconfig.json` extending the shared base. Path aliases must be configured in both tsconfig AND the bundler.

## Anti-Patterns

- DO NOT put all dependencies in root — only truly shared ones.
- DO NOT create circular dependencies between packages. If A depends on B and B depends on A, merge them or extract the shared part.
- DO NOT skip `outputs` in `turbo.json` — Turbo can't cache without it.
- DO NOT have packages reach into each other's internals. Use the exported API.
- DO NOT make one mega `utils` package — split by domain: `@repo/date-utils`, `@repo/string-utils`.
- DO NOT add Turbo as a dependency per package — it's a root-level orchestrator.
