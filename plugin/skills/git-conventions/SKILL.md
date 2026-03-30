---
name: git-conventions
description: Git workflow conventions — conventional commits, branching, atomic commits, clean history.
---

# Git Conventions

Git history is documentation. If your commit log reads like "fix stuff", "wip", "asdqwe", you're leaving a mess for future developers — including yourself.

## Conventional Commits

Every commit message follows this format:
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
| Type | When |
|------|------|
| `feat` | New feature for the user |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `docs` | Documentation only |
| `test` | Adding or correcting tests |
| `chore` | Build, CI, tooling, deps — no production code |
| `style` | Formatting, whitespace — no logic change |
| `perf` | Performance improvement |

### Examples
```
feat(auth): add OAuth2 login with Google
fix(cart): prevent negative quantity on item update
refactor(api): extract validation middleware from controllers
docs(readme): add deployment instructions
test(user): add edge cases for email validation
chore(deps): bump vite to 6.1.0
```

### Breaking Changes
- Use `!` after type: `feat(api)!: change response format for /users`
- Or add `BREAKING CHANGE:` in the footer.

## Commit Message Body

- The diff shows WHAT changed. The body explains **WHY**.
- Good body: "The previous approach loaded all users into memory, causing OOM on large datasets. Switched to cursor-based pagination."
- Bad body: "Changed the query to use cursors instead of offset."
- If the why is obvious from the description, skip the body.

## Atomic Commits

- **One logical change per commit.** Not one file, not one function — one logical change.
- If you're fixing a bug AND refactoring nearby code, that's TWO commits.
- If you can't describe the commit in one line without "and", it's too big.
- Small commits are easier to review, easier to revert, easier to bisect.

## Branch Naming

```
feature/AUTH-123-oauth-login
fix/CART-456-negative-quantity
refactor/api-validation-middleware
docs/deployment-guide
chore/upgrade-vite-6
```

- Prefix with category: `feature/`, `fix/`, `refactor/`, `docs/`, `chore/`.
- Include ticket number when available.
- Use kebab-case for the description.
- Keep it short but descriptive.

## Branch Strategy

- `main` — always deployable. Protected. No direct pushes.
- `develop` — integration branch (if using gitflow). Optional for trunk-based.
- Feature branches — short-lived. Merge within days, not weeks.

### Rules
- **Never force push to `main` or `develop`.** Period.
- **Rebase over merge** for keeping feature branch up to date:
  ```bash
  git fetch origin
  git rebase origin/main
  ```
- **Squash merge** when merging feature branches to main — one clean commit per feature.
- Resolve conflicts during rebase, not at merge time.

## Pull Requests

- PR title follows conventional commit format: `feat(auth): add OAuth2 login`.
- PR description explains:
  - **What** changed and **why**
  - **How to test** it
  - **Screenshots** if UI changed
- Keep PRs small. 200-400 lines of actual code is ideal. Over 800 lines is too big to review properly.
- Request review from someone who owns that area of the codebase.

## Tags and Releases

- Tag releases with semver: `v1.2.3`.
- `MAJOR` — breaking changes.
- `MINOR` — new features, backward compatible.
- `PATCH` — bug fixes.
- Use annotated tags:
  ```bash
  git tag -a v1.2.3 -m "Release v1.2.3: OAuth login, cart fixes"
  ```

## Housekeeping

- Delete merged branches — both local and remote.
- Don't commit generated files (dist, build, coverage, node_modules).
- `.gitignore` is not optional — set it up on day one.
- Use `.gitattributes` for line ending consistency across OS.

## Anti-Patterns

- DO NOT commit "WIP" to shared branches. Use local commits and squash before pushing.
- DO NOT use `git add .` blindly — review what you're staging.
- DO NOT rewrite history on shared branches (rebase/amend after push).
- DO NOT leave stale branches — if it's merged or abandoned, delete it.
- DO NOT commit secrets. Not even temporarily. Git remembers everything.
- DO NOT use merge commits for updating feature branches — rebase instead.
