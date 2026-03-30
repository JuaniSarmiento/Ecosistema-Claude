---
name: api-rest
description: REST API design — resource naming, HTTP methods, status codes, pagination, error handling.
---

# REST API Design

A well-designed API is intuitive. If a developer needs to read documentation for every endpoint, the design failed.

## Resource Naming

- **Resources are NOUNS, not verbs.** The HTTP method is the verb.
  ```
  GET    /users          ← list users
  POST   /users          ← create user
  GET    /users/:id      ← get user
  PUT    /users/:id      ← replace user
  PATCH  /users/:id      ← partial update
  DELETE /users/:id      ← delete user
  ```
- **Never:** `/getUsers`, `/createUser`, `/deleteUser`. The method already tells you the action.
- Use plural nouns: `/users` not `/user`.
- Nested resources for clear relationships: `/users/:id/orders`.
- Max 2 levels of nesting. Beyond that, promote the sub-resource: `/orders?userId=123`.

## HTTP Methods

| Method | Purpose | Idempotent | Body |
|--------|---------|------------|------|
| GET | Read | Yes | No |
| POST | Create | No | Yes |
| PUT | Full replace | Yes | Yes |
| PATCH | Partial update | No* | Yes |
| DELETE | Remove | Yes | No |

- **GET must NEVER have side effects.** No creating, no updating, no deleting on GET.
- **PUT replaces the entire resource.** If you send a PUT without a field, that field is removed.
- **PATCH updates only the sent fields.** Use this for partial updates.
- **POST is not idempotent.** Two identical POSTs may create two resources.

## Status Codes (USE THEM CORRECTLY)

| Code | When |
|------|------|
| `200 OK` | Successful GET, PUT, PATCH |
| `201 Created` | Successful POST — include `Location` header |
| `204 No Content` | Successful DELETE or action with no response body |
| `400 Bad Request` | Malformed request (invalid JSON, missing required field) |
| `401 Unauthorized` | No authentication (actually means "unauthenticated") |
| `403 Forbidden` | Authenticated but not authorized |
| `404 Not Found` | Resource doesn't exist |
| `409 Conflict` | State conflict (duplicate email, version mismatch) |
| `422 Unprocessable Entity` | Valid JSON but fails validation (email format, min length) |
| `429 Too Many Requests` | Rate limited |
| `500 Internal Server Error` | Unhandled server error — never intentional |

- Don't return 200 for everything with `{ success: false }`. That's an anti-pattern.
- 4xx is client's fault. 5xx is server's fault. Get this right.

## Error Response Format

Use a consistent format across ALL endpoints:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email format is invalid",
    "details": [
      { "field": "email", "message": "Must be a valid email address" }
    ]
  }
}
```
- `code` — machine-readable constant (for client error handling).
- `message` — human-readable description.
- `details` — optional array for field-level validation errors.
- Never expose stack traces or internal errors to the client.

## Pagination

- **Cursor-based for large or real-time datasets:**
  ```
  GET /posts?limit=20&cursor=eyJpZCI6MTIzfQ
  ```
  Response includes:
  ```json
  { "data": [...], "pagination": { "next_cursor": "eyJpZCI6MTQzfQ", "has_more": true } }
  ```
- **Offset-based only for small, static datasets:**
  ```
  GET /posts?limit=20&offset=40
  ```
- Cursor is better because: no skipped/duplicated items on insert, consistent performance regardless of page number.

## Filtering and Sorting

- Filter via query params: `GET /users?status=active&role=admin`.
- Sort with `sort` param: `GET /users?sort=-created_at` (prefix `-` for descending).
- Multiple sorts: `GET /users?sort=-created_at,name`.
- Search: `GET /users?q=john` for full-text search.

## Versioning

- Version in the URL: `/v1/users`. Simple, explicit, cacheable.
- Don't use header-based versioning unless you have a strong reason — it's less discoverable.
- Don't break existing versions. Deprecate with warnings, migrate clients, then sunset.

## Rate Limiting

- Include rate limit headers in EVERY response:
  ```
  X-RateLimit-Limit: 100
  X-RateLimit-Remaining: 87
  X-RateLimit-Reset: 1700000000
  ```
- Return `429 Too Many Requests` with `Retry-After` header when exceeded.
- Rate limit by API key or authenticated user, not just IP.

## Request/Response Conventions

- Use `camelCase` for JSON keys (JavaScript ecosystem standard).
- Include `id` in every resource response.
- Timestamps in ISO 8601: `"2024-01-15T10:30:00Z"`.
- Wrap collections: `{ "data": [...], "pagination": {...} }`, not bare arrays.
- Include `Content-Type: application/json` header.

## HATEOAS

- Only implement if your client actually navigates links. Most SPAs don't.
- If used: include `_links` with `self`, `next`, `related` — but don't cargo cult it.

## Anti-Patterns

- DO NOT use verbs in URLs (`/getUser`, `/deletePost`).
- DO NOT return 200 with `{ success: false, error: "..." }`.
- DO NOT use GET for mutations (creating, updating, deleting).
- DO NOT expose database IDs as sequential integers — use UUIDs or nano IDs.
- DO NOT nest resources deeper than 2 levels.
- DO NOT return different response shapes for the same endpoint based on conditions.
