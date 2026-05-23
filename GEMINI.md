# BigPowers-Benchmark — Gemini CLI

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
HTML/CSS/JS prototypes in `project/` serve as pixel-perfect design references; the real app is a native SwiftUI macOS app built around a `NavigationSplitView` shell with `Table` for data grids, Swift Charts for score visualizations, a `Canvas+Path` skill radar, an `NSViewRepresentable(NSTextView)` ANSI terminal panel, and a `Process+Pipe+AsyncStream` benchmark runner that writes `BenchRow` JSON shards to `~/runs/data/`.

## Conventions
- Follow bigpowers principles in all phases.
- All planning and specs live in `specs/`.
- Use countable-story-format.md for any story or bug spec.
- TDD: write the failing test first, make it pass, then refactor.
- Match the HTML prototypes in `project/` pixel-for-pixel.
- API keys go to Keychain only — never to files or committed code.

## Never
- Never write code directly in response to a user prompt — run the appropriate bigpowers skill first.
- Never commit to `main` directly.
- Never skip tests or declare done without evidence.
- Never write code outside the current task scope.
- Never write API keys or secrets to any file.
- Never use `--no-verify` to bypass git hooks.
- Never touch `project/` HTML files — read-only design references.

## Agent Rules
- **Workflow Mandate:** Use bigpowers skills to perform tasks. DO NOT write code directly.
- Read `specs/` before writing any code.
- All planning MUST be written to `specs/` before any code is generated.
- Write the minimum code that solves the stated problem. Nothing extra.
- Never refactor or reorganize code outside the task scope.
- Run tests after every change. Show evidence before declaring done.
- One clarifying question beats a wrong assumption baked into 200 lines.
