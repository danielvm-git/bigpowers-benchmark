# Git Hooks & Release Automation

## Hook manager: Lefthook 2.1.8

Installed via Homebrew. Config: `lefthook.yml` at repo root.
Re-run `lefthook install` after any clone to sync `.git/hooks/`.

## Hooks

| Hook | Tool | What it does |
|------|------|-------------|
| `pre-commit` | SwiftFormat 0.61.1 | Auto-formats staged `.swift` files; re-stages them |
| `pre-commit` | SwiftLint 0.63.2 | Auto-fixes then strictly lints staged `.swift` files |
| `commit-msg` | commitlint 21 | Rejects commit messages that don't follow Conventional Commits |
| `pre-push` | `swift test` | Runs the full test suite before any push |

## Conventional Commits

Enforced by `commitlint.config.cjs` using `@commitlint/config-conventional`.

Allowed types: `feat` `fix` `docs` `style` `refactor` `test` `chore` `perf` `ci` `build` `revert`

Rules:
- `subject-case`: lower-case
- `header-max-length`: 100

### Interactive commit helper

```bash
npm run commit   # launches commitizen (guided conventional commit prompt)
```

## Semantic Release

Config: `.releaserc.json`

Triggered by CI on push to `main`. Never run locally.

| Plugin | Purpose |
|--------|---------|
| `@semantic-release/commit-analyzer` | Determines next semver bump from commit types |
| `@semantic-release/release-notes-generator` | Generates release notes |
| `@semantic-release/changelog` | Writes/updates `CHANGELOG.md` |
| `@semantic-release/git` | Commits `CHANGELOG.md` back to repo |
| `@semantic-release/github` | Publishes GitHub Release with notes |

`@semantic-release/npm` is intentionally **not** used (this is a Swift app, not an npm package).

## CI (GitHub Actions)

Workflow: `.github/workflows/release.yml`

Triggers on every push to `main`. Requires no extra secrets — `GITHUB_TOKEN` is provided automatically by Actions with `contents: write` and `pull-requests: write` permissions.

Key flags:
- `fetch-depth: 0` — semantic-release needs full git history to compute the version bump
- `persist-credentials: false` — required so the `@semantic-release/git` plugin can push the changelog commit back using its own token

## Tool configs

| File | Purpose |
|------|---------|
| `lefthook.yml` | Hook definitions |
| `.releaserc.json` | Semantic release pipeline |
| `commitlint.config.cjs` | Commit message rules |
| `.swiftlint.yml` | SwiftLint rules |
| `.swiftformat` | SwiftFormat rules |
