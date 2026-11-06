# BigPowers-Benchmark — Agent Spine

Read CONVENTIONS.md before any GitHub or git operation.

## Project
BigPowers-Benchmark — a native macOS app that benchmarks AI coding agents.
Stack: Swift / SwiftUI / macOS 14+ (Profile: swift)

## Session Start
At the start of every session, read in order:
1. `CLAUDE.md` / `AGENTS.md`
2. `CONVENTIONS.md`
3. `specs/state.yaml`
4. `specs/release-plan.yaml`

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

## Observability

| What | Command |
|------|---------|
| Tail debug log | `tail -f ~/Library/Logs/BigPowersBenchmark/debug.ndjson` |
| Copy for AI | App menu **Help → Copy Debug Log** (⇧⌘L) |
| Reveal log file | App menu **Help → Reveal Log File** |
| Recent runs | `ls -t ~/runs/data/*.json \| head -5` |
| Check runner | `opencode --version` |
| Check sandbox | `daytona workspace list` |

## Architecture
HTML/CSS/JS prototypes in `specs/assets/prototypes/` serve as pixel-perfect design references; the real app is a native SwiftUI macOS app built around a `NavigationSplitView` shell with `Table` for data grids, Swift Charts for score visualizations, a `Canvas+Path` skill radar, an `NSViewRepresentable(NSTextView)` ANSI terminal panel, and a `Process+Pipe+AsyncStream` benchmark runner that writes `BenchRow` JSON shards to `~/runs/data/`.

## Conventions
- Follow bigpowers principles in all phases.
- All planning and specs live in `specs/` — never inline in code or chat.
- Use countable-story-format.md for any story or bug spec.
- TDD: write the failing test first, make it pass, then refactor.
- Match the HTML prototypes in `specs/assets/prototypes/` pixel-for-pixel.
- API keys go to Keychain only — never to files or committed code.
- Workflow mode: `solo-git`.

## Never
- Never write code directly in response to a user prompt — run the appropriate bigpowers skill first.
- Never commit to `main` directly.
- Never skip tests or declare done without evidence.
- Never write code outside the current task scope.
- Never write API keys or secrets to any file.
- Never modify generated code, vendored dependencies, or database migrations directly without an explicit migration plan.
- Never use `--no-verify` to bypass git hooks.
- Never touch `specs/assets/prototypes/` HTML files — read-only design references.
- Never add `Co-authored-by:` or `Co-Authored-By:` trailers to commit messages.

## Agent Rules
- **Workflow Mandate:** Use bigpowers skills to perform tasks. DO NOT write code directly.
- Read `specs/` before writing any code.
- All planning MUST be written to `specs/` before any code is generated.
- Write the minimum code that solves the stated problem. Nothing extra.
- Never refactor or reorganize code outside the task scope.
- Run tests after every change. Show evidence before declaring done.
- One clarifying question beats a wrong assumption baked into 200 lines.
- Defensive code applies where the system boundary warrants it: Timeout on all Process/network calls; Retry with backoff on API calls; Graceful degradation when the benchmark runner is unavailable.
