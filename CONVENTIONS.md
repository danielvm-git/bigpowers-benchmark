# BigPowers-Benchmark — Conventions

These rules apply to every contributor: human or agent.

---

## Commands

| Action | Command |
|--------|---------|
| Run    | `swift run BigPowersBenchmark` |
| Test   | `swift test` |
| Build  | `swift build` |
| Lint   | `lefthook run pre-commit` |
| Preflight | `swift test && lefthook run pre-commit && swift build` |
| A/B dry run | `bash scripts/run-ab-eval.sh --dry-run --bigpowers-root /path/to/bigpowers` |
| A/B tests | `python3 Tests/test_ab_eval.py && python3 Tests/test_ab_score.py` |
| A/B sandbox | `bash scripts/ab-sandbox.sh status` |

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

## 7. Git discipline & workflow mode

- Workflow mode: `solo-git` (see `specs/WORKFLOW-solo-git.md`).
- All work on a feature branch — never commit directly to `main`.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `test:`, `chore:`, etc.).
- Never use `--no-verify` or `--force-push` to `main`.
- Pre-commit hooks must pass before any commit lands.

## 8. Scope discipline

- Write the minimum code that solves the stated problem.
- Never refactor, rename, or reorganize code outside the current task scope.
- Three similar lines is better than a premature abstraction.

## 9. Never-do list

- Never write code directly in response to a user prompt — always run the appropriate bigpowers skill first.
- Never commit to `main` directly — all work goes through a feature branch.
- Never skip tests or declare done without evidence.
- Never write code outside the current task scope.
- Never write API keys, secrets, or tokens to any file.
- Never modify generated code, vendored dependencies, or database migrations directly without an explicit migration plan.
- Never use `--no-verify` to bypass git hooks.
- Never touch `specs/assets/prototypes/` or `project/` HTML files — they are read-only design references (chmod 444).
- Never add `Co-authored-by:` or `Co-Authored-By:` trailers to commit messages.

## 10. Stack profile

- Profile: `swift` (macOS 14+, Swift 6 concurrency, Swift Testing / XCTest, SwiftUI NavigationSplitView).

## 11. Comments

- Default: no comments.
- Add a comment only when the WHY is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug).
- Never describe WHAT the code does — well-named identifiers do that.

## 12. Accessibility

- Target WCAG 2.1 AA.
- Honor `@Environment(\.accessibilityReduceMotion)` for all animations.
- All interactive elements must be keyboard-focusable and VoiceOver-labeled.

## 13. Output directory

All skill output (plans, specs, investigation reports, refactor notes) goes to `specs/`. Never write intermediate planning documents to the repo root or inside `project/`.
