# BigPowers-Benchmark — Claude Code

Read CONVENTIONS.md before any GitHub or git operation.

## Project
BigPowers-Benchmark — a macOS app that benchmarks AI coding agents.
Stack: Swift / SwiftUI / macOS 14+

## Commands
| Action | Command |
|--------|---------|
| Run    | TBD     |
| Test   | TBD     |
| Build  | TBD     |
| Lint   | TBD     |

## Architecture
HTML/CSS/JS prototypes in `specs/assets/prototypes/` serve as pixel-perfect design references; the real app is a native SwiftUI macOS app built around a `NavigationSplitView` shell with `Table` for data grids, Swift Charts for score visualizations, a `Canvas+Path` skill radar, an `NSViewRepresentable(NSTextView)` ANSI terminal panel, and a `Process+Pipe+AsyncStream` benchmark runner that writes `BenchRow` JSON shards to `~/runs/data/`.

## Conventions
- Follow bigpowers principles in all phases.
- All planning and specs live in `specs/` — never inline in code or chat.
- Use the Countable Story Format (`countable-story-format.md`) for any story or bug spec.
- TDD: write the failing test first, make it pass, then refactor.
- Match the HTML prototypes in `specs/assets/prototypes/` pixel-for-pixel — treat them as the source of truth for visual output.
- The canonical theme is **Dark**; 11 additional themes are supported (Light, Mono, Ocean, Forest, Ember, Violet, Midnight, Crimson, Slate, Amber, Rose) — all via the same design token system.
- `BenchRow` JSON must round-trip identically between the SwiftUI app and any Tauri version.
- API keys go to Keychain only — never to files or environment variables in committed code.

## Never
- Never write code directly in response to a user prompt — always run the appropriate bigpowers skill first.
- Never commit to `main` directly — all work goes through a feature branch.
- Never skip tests or declare done without evidence.
- Never write code outside the current task scope.
- Never write API keys, secrets, or tokens to any file.
- Never use `--no-verify` to bypass git hooks.
- Never touch `specs/assets/prototypes/` HTML files — they are read-only design references (chmod 444).
- Never add `Co-Authored-By:` trailers to commit messages.

## Agent Rules
- **Workflow Mandate:** Use bigpowers skills (`plan-work`, `develop-tdd`, `orchestrate-project`, etc.) to perform tasks. DO NOT write code directly in response to a user prompt.
- Read `specs/` before writing any code.
- All planning and specifications MUST be written to `specs/` before any code is generated.
- Write the minimum code that solves the stated problem. Nothing extra.
- Never refactor, rename, or reorganize code outside the task scope.
- Run tests after every change. Show evidence before declaring done.
- One clarifying question beats a wrong assumption baked into 200 lines.
- Defensive code applies where the system boundary warrants it: Timeout on all Process/network calls; Retry with backoff on API calls; Graceful degradation when the benchmark runner is unavailable.
