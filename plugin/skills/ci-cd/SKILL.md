---
name: ci-cd
description: CI/CD patterns with GitHub Actions — fail fast, caching, secrets, branch protection, automated releases.
---

# CI/CD (GitHub Actions)

Your CI pipeline is the quality gate. If it doesn't catch problems before merge, it's decoration.

## Pipeline Philosophy

- **Fail fast.** Cheap checks first, expensive checks last:
  1. Lint + type-check (~30s)
  2. Unit tests (~1-3min)
  3. Integration tests (~3-5min)
  4. Build (~2-5min)
  5. E2E tests (~5-10min)
- If linting fails, don't waste 10 minutes running E2E tests.

## Workflow Structure

- Separate workflows by trigger:
  ```
  .github/workflows/
  ├── ci.yml           # On PR: lint, test, build
  ├── deploy.yml       # On merge to main: deploy
  └── release.yml      # On tag: publish, create release
  ```
- CI runs on every PR. Deploy runs only on merge to main. Release runs on version tags.

## CI Workflow Example

```yaml
name: CI
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm

      - run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Type Check
        run: pnpm type-check

      - name: Unit Tests
        run: pnpm test -- --coverage

      - name: Build
        run: pnpm build

      - name: Upload Coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
```

## Concurrency

- **Cancel in-progress runs** when a new commit is pushed to the same PR:
  ```yaml
  concurrency:
    group: ci-${{ github.ref }}
    cancel-in-progress: true
  ```
- This prevents wasting CI minutes on outdated commits.
- DON'T cancel on main branch — you want every merge verified.

## Caching

- **Cache node_modules:**
  ```yaml
  - uses: actions/setup-node@v4
    with:
      node-version: 20
      cache: pnpm  # Built-in pnpm caching
  ```
- **Cache Turbo:**
  ```yaml
  - uses: actions/cache@v4
    with:
      path: .turbo
      key: turbo-${{ runner.os }}-${{ hashFiles('**/pnpm-lock.yaml') }}
      restore-keys: turbo-${{ runner.os }}-
  ```
- **Cache Next.js:**
  ```yaml
  - uses: actions/cache@v4
    with:
      path: apps/web/.next/cache
      key: nextjs-${{ runner.os }}-${{ hashFiles('**/pnpm-lock.yaml') }}
  ```
- Cache keys should include the lockfile hash so they bust when deps change.

## Secrets

- **Store ALL secrets in GitHub Secrets.** Never in workflow files, never in repo.
- Access via `${{ secrets.MY_SECRET }}`.
- Secrets are masked in logs automatically.
- Use environment-specific secrets for staging vs production:
  ```yaml
  environment: production
  env:
    DATABASE_URL: ${{ secrets.PROD_DATABASE_URL }}
  ```
- **Rotate secrets periodically.** If a secret leaks, rotate immediately.

## Branch Protection

- **Main branch MUST be protected:**
  - Require PR reviews (at least 1)
  - Require status checks to pass (CI workflow)
  - Require branches to be up to date
  - No direct pushes
  - No force pushes
- These rules exist so nobody can merge broken code. No exceptions.

## Matrix, Previews, Releases

- **Matrix** — only when you genuinely support multiple runtimes (npm libraries). For apps, pick one Node version. Matrix triples CI time.
- **Deploy previews** — use Vercel/Netlify for automatic PR preview URLs. Use staging data, never production.
- **Automated releases** — use semantic-release or changesets. Version from commit messages, changelog auto-generated.
- **Artifacts** — upload test results and coverage with `actions/upload-artifact@v4`. Use `if: always()` so reports are saved even on failure.

## Anti-Patterns

- DO NOT put secrets in plain text anywhere in the repo.
- DO NOT run everything in a single job — parallel jobs finish faster.
- DO NOT skip CI for "small changes." Small changes break things too.
- DO NOT use `continue-on-error: true` to hide failures. Fix them.
- DO NOT install dependencies without `--frozen-lockfile`. You need reproducible builds.
- DO NOT run E2E tests on every commit during active development — use `on: pull_request` only.
- DO NOT ignore flaky tests. A CI pipeline you can't trust is useless.
