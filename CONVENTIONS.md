# BigPowers-Benchmark — Conventions

These rules apply to every contributor: human or agent.

---

## 1. Specs first

All planning, stories, bug specs, and architecture decisions go in `specs/` before any code is written. The canonical story format is `countable-story-format.md` (at the repo root). A spec that is not Countable (maturity ≥ 3) is not sprint-ready.

## 2. TDD — red-green-refactor

1. Write a failing test that captures the requirement.
2. Write the minimum code to make it pass.
3. Refactor only within the green state.

No code ships without a corresponding test. Evidence (test output) is required before declaring done.

## 3. Design fidelity

- `specs/assets/prototypes/*.html` files are the source of truth for visual output. Treat them as read-only.
- Match colors, spacing, typography, and interaction states pixel-for-pixel.
- The canonical theme is **Dark**. All 12 themes must be supported via the design token system: Dark, Light, Mono, Ocean, Forest, Ember, Violet, Midnight, Crimson, Slate, Amber, Rose.

## 4. Data contract

- `BenchRow` JSON shards must round-trip identically with any other version of the app.
- Score formula: `overallScore = (codePass * 2 + artifactScore + conventionScore) / 4`
- JSON shards live in `~/runs/data/`. Never change the field names or types without a migration spec.

## 5. Security

- API keys go to **Keychain only** (`SecItemAdd` / `SecItemCopyMatching`).
- Never write secrets to any file, environment variable in committed code, or log output.
- Never commit `.env` files or credentials.

## 6. Defensive code

Apply at every system boundary:

| Category           | Where it applies                                      |
|--------------------|-------------------------------------------------------|
| Timeout            | All `Process` launches, network/API calls             |
| Retry with backoff | Outbound API calls (model providers)                  |
| Graceful degradation | When benchmark runner (`opencode`) is unavailable   |

## 7. Git discipline

- All work on a feature branch — never commit directly to `main`.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `test:`, `chore:`, etc.).
- Never use `--no-verify` or `--force-push` to `main`.
- Pre-commit hooks must pass before any commit lands.

## 8. Scope discipline

- Write the minimum code that solves the stated problem.
- Never refactor, rename, or reorganize code outside the current task scope.
- Three similar lines is better than a premature abstraction.

## 9. Comments

- Default: no comments.
- Add a comment only when the WHY is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug).
- Never describe WHAT the code does — well-named identifiers do that.

## 10. Accessibility

- Target WCAG 2.1 AA.
- Honor `@Environment(\.accessibilityReduceMotion)` for all animations.
- All interactive elements must be keyboard-focusable and VoiceOver-labeled.

## 11. Output directory

All skill output (plans, specs, investigation reports, refactor notes) goes to `specs/`. Never write intermediate planning documents to the repo root or inside `project/`.
