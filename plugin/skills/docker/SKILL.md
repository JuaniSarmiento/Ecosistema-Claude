---
name: docker
description: Docker and containerization — multi-stage builds, layer caching, security, compose for dev.
---

# Docker

Containers are infrastructure as code. Treat your Dockerfile like production code — no shortcuts, no "it works on my machine."

## Dockerfile — Multi-Stage Builds

- **Always use multi-stage builds.** Build stage installs dev deps and compiles. Runner stage is minimal.
  ```dockerfile
  # Stage 1: Build
  FROM node:20-alpine AS builder
  WORKDIR /app
  COPY package*.json ./
  RUN npm ci
  COPY . .
  RUN npm run build

  # Stage 2: Run
  FROM node:20-alpine AS runner
  WORKDIR /app
  ENV NODE_ENV=production
  RUN addgroup -S appgroup && adduser -S appuser -G appgroup
  COPY --from=builder /app/dist ./dist
  COPY --from=builder /app/node_modules ./node_modules
  COPY --from=builder /app/package.json ./
  USER appuser
  EXPOSE 3000
  HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
  CMD ["node", "dist/index.js"]
  ```

## Layer Caching

- **COPY dependency files FIRST, install, THEN copy source code.**
  ```dockerfile
  COPY package.json package-lock.json ./
  RUN npm ci
  COPY . .
  ```
- This way, `npm ci` only re-runs when dependencies change, not on every code change.
- Use `npm ci` (clean install), never `npm install` in Docker — it's deterministic and respects lockfile.
- Order Dockerfile instructions from least-changing to most-changing.

## .dockerignore (Mandatory)

- Every project with a Dockerfile MUST have a `.dockerignore`:
  ```
  node_modules
  .git
  .env
  .env.*
  dist
  coverage
  .next
  *.log
  .DS_Store
  ```
- Without it, you're copying gigabytes of garbage into your build context.

## Security

- **Non-root user in production.** Always create and switch to a non-root user:
  ```dockerfile
  RUN addgroup -S appgroup && adduser -S appuser -G appgroup
  USER appuser
  ```
- **Use specific image tags.** `node:20.11-alpine`, not `node:latest`. `latest` is a moving target — your build will break silently.
- Never store secrets in the image. No `ENV SECRET_KEY=...` in Dockerfile.
- Use `--no-cache` for sensitive builds to avoid caching credentials in layers.
- Scan images for vulnerabilities: `docker scout cves <image>`.

## Health Checks

- Every production container needs a health check:
  ```dockerfile
  HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:3000/health || exit 1
  ```
- The health endpoint should check real dependencies (DB connection, critical services), not just return 200.

## Docker Compose — Local Dev

- Compose is for local development and testing. NOT for production orchestration.
  ```yaml
  services:
    app:
      build: .
      ports:
        - "3000:3000"
      env_file: .env
      volumes:
        - .:/app
        - /app/node_modules
      depends_on:
        db:
          condition: service_healthy

    db:
      image: postgres:16-alpine
      environment:
        POSTGRES_DB: ${DB_NAME}
        POSTGRES_USER: ${DB_USER}
        POSTGRES_PASSWORD: ${DB_PASSWORD}
      volumes:
        - pgdata:/var/lib/postgresql/data
      healthcheck:
        test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
        interval: 5s
        timeout: 3s

  volumes:
    pgdata:
  ```

## Environment Variables

- **Never hardcode env vars in compose or Dockerfile.** Use `env_file: .env`.
- Use `.env.example` committed to repo with placeholder values. `.env` is in `.gitignore`.
- For compose, reference env vars with `${VAR_NAME}` syntax.

## Volumes

- **Named volumes for persistent data** (databases, uploads):
  ```yaml
  volumes:
    pgdata:
  ```
- **Bind mounts for dev** (live reload):
  ```yaml
  volumes:
    - .:/app
    - /app/node_modules  # Prevent overwriting container's node_modules
  ```
- The `/app/node_modules` anonymous volume trick prevents the bind mount from overwriting the container's installed dependencies.

## Image and Networking

- Use Alpine variants — they're 5-10x smaller. Pin versions: `node:20.11-alpine`.
- Remove cache after system packages: `RUN apk add --no-cache curl`.
- Services in the same compose file share a network. Reference by service name: `postgres://db:5432/myapp`.
- Only expose ports when needed — internal services don't need `ports:`.

## Anti-Patterns

- DO NOT use `latest` tag in production images.
- DO NOT run as root in production containers.
- DO NOT put secrets in Dockerfile or compose files.
- DO NOT use `docker-compose` for production — use Kubernetes, ECS, or similar.
- DO NOT skip `.dockerignore` — it's not optional.
- DO NOT use `ADD` when `COPY` suffices. `ADD` has magic behaviors (tar extraction, URL fetching) you don't want.
