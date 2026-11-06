# Hacker News / HackerRank task ideas

Collected 2026-11-04. HackerRank content and CodeCrafters lessons are proprietary: use them as
inspiration, write our own spec, fixture, reference solution and tests. Hacker News posts are
cited only as idea sources.

## Threads worth mining

| Thread | Idea |
|---|---|
| [Challenging projects every programmer should try](https://news.ycombinator.com/item?id=21790779) | Implement a specification: TTF renderer, GIF/JPEG decoder, video decoder. |
| [CodeCrafters launch](https://news.ycombinator.com/item?id=32342334) | Build Redis, Git, Docker, SQLite from scratch; tests assert observable behaviour. |
| [Learn by rebuilding Redis, Git, a database](https://news.ycombinator.com/item?id=48871973) | 80+ courses, starter code + `run_tests.sh`, real specs per lesson. |
| [SLCR — sliceable, linked, checkable requirements](https://news.ycombinator.com/item?id=50291963) | MIT spec format; requirement DAG + acceptance criteria. Good spec-shape reference. |
| [Spec-Driven Development Workflow for Claude Code](https://news.ycombinator.com/item?id=48231575) | Requirements → code analysis → design → subtasks; session isolation. |
| [Specification First Agentic Development](https://news.ycombinator.com/item?id=50260571) | Spec-first examples; checkpoint/resume spec with atomic writes. |
| [Specific — backends from specifications](https://news.ycombinator.com/item?id=45595760) | HTTP + DB + external APIs from a spec; tests as part of the spec. |
| [Rune spec pattern](https://news.ycombinator.com/item?id=47015481) | WHEN/THEN behaviour + test cases; inconsistent-model-output framing. |
| [Yass spec syntax](https://news.ycombinator.com/item?id=49812577) | RFC-2119 keywords, byte-exact output across 7 languages. |
| [Kiro spec-driven IDE](https://news.ycombinator.com/item?id=44560662) | Requirements/design/tasks triad; medium-sized sample repo. |
| [Problems with Swagger](https://news.ycombinator.com/item?id=14035936) | Spec as source of truth; implement/validate an API from an OpenAPI file. |
| [HackerRank Sorted Set](https://www.hackerrank.com/challenges/sortedset/problem) | Networked sorted set, binary protocol, multiple clients. |
| [HackerRank Basic Spell Checker](https://www.hackerrank.com/challenges/basic-spell-checker/problem) | Corpus + frequency + edit distance. |

## Task candidates, ranked for this harness

### 1. Checkpointed resumable worker — Node/Python, mid

Inspired by the HN checkpoint spec (atomic writer, schema version, resume, failure handling).

- A downloader/worker processes a list of jobs from a checkpoint file.
- Requirements: atomic checkpoint write (temp + fsync + rename), schema version, resume from the
  last completed index, reject malformed/unsupported checkpoints, preserve the old checkpoint on
  failure, injectable clock/http, deterministic output.
- Hidden tests: kill mid-run and resume, corrupt checkpoint, version mismatch, duplicate work,
  partial output, concurrent run lock.
- Why it may discriminate: correctness is in **crash safety and resume**, not endpoint count.

### 2. Mini Redis / networked sorted set — Node/Python, mid/hard

Inspired by HackerRank Sorted Set + CodeCrafters Redis.

- TCP server with a small RESP-like or binary protocol.
- Commands: set/get, ZADD, ZRANGE (by score and key), size, remove, disconnect.
- Requirements: multiple concurrent clients, persistent connection state, ordering, score
  updates, unknown commands, partial frames, graceful disconnect.
- Hidden tests: concurrent clients, pipelining, partial TCP frames, ordering, update semantics,
  disconnect cleanup.
- Why it may discriminate: protocol framing and concurrency are hard to fake with a single-file
  implementation.

### 3. Mini Git object store — Node/Python, mid/hard

Inspired by CodeCrafters Git.

- Content-addressed blobs, trees, commits, refs; SHA-1/SHA-256; read/write pack-free objects.
- Requirements: object hashing, tree ordering, commit parent, ref update atomicity, cat-file.
- Hidden tests: round-trip, nested trees, duplicate blobs, corrupt object, missing parent, ref
  update rollback.
- Why it may discriminate: binary layout + invariants + atomic ref updates.

### 4. API from an OpenAPI spec — Node, mid

Inspired by the HN Swagger thread.

- Ship a small `openapi.yaml` and an empty app; implement routes, validation and error shape.
- Hidden tests: every documented status code, schema validation, unknown fields, content type.
- Why it may discriminate: the agent must read the spec rather than the tests.

### 5. Rate-limited job queue — Node/Python, mid

- Enqueue jobs, workers, retries with backoff, idempotency keys, dead-letter, rate limit.
- Hidden tests: retry counts, no duplicate side effects, concurrent workers, persistence across
  restart, dead-letter ordering.

### 6. TTF / GIF decoder — any, hard

- Implement a small subset from the format spec; hidden tests on fixture bytes.
- Likely too large for the current 1800 s timeout; keep as a stretch task.

### 7. Spell checker — small, control

- Corpus frequency + edit distance. Useful as a warm-up/control; likely too easy alone.

## Selection rule

Prefer tasks where the hard part is **state, concurrency, atomicity, protocol or recovery**.
Our recent calibration showed that more endpoints and more files do not make a task harder for
this model; crash safety and concurrency are more likely to discriminate.

## Licensing

- HackerRank challenges and CodeCrafters lessons: **do not copy**; write original specs,
  fixtures and tests.
- HN-linked MIT/Apache projects (SLCR, proto-specs, SpecBench, intent-bench): adapt with
  attribution.
- Keep the source/commit/licence in `task.yaml` when a task is adapted.
