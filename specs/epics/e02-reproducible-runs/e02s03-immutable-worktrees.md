# e02s03 — Run subject and runner inputs from immutable detached worktrees
<!-- story: e02s03 -->

**type:** feat
**risk:** P1
**context:** infra
**BCPs:** 5

## Context

A concurrent session on the host bigpowers repo can switch branches or edit files while a benchmark
is running. A `git worktree add --detach HEAD` snapshot removes that race for the subject. The runner
inputs (`benchmarks/`, `scripts/`) get the same treatment when `--runner-worktree` is set.

## Steps

1. Add `scripts/lib/ab-worktree.sh`: `create_subject_worktree <repo> <sha> <dir>`, `remove_worktree` with a `trap` on EXIT/INT/TERM → verify: `bash -n scripts/lib/ab-worktree.sh`.
2. In `run-ab-eval.sh`, create the worktree before exec, export `AB_BP_ROOT` to it, and clean up on every exit path → verify: `bash scripts/run-ab-eval.sh --dry-run --bigpowers-root /tmp/bp-subject | rg 'worktrees/'`.
3. If the subject is dirty and `--allow-dirty` is set, `rsync -a --exclude .git` into a temp dir instead; warn and record the dirty hash → verify: `python3 Tests/test_ab_provenance.py`.
4. Add `--runner-worktree`: detach a worktree of this repo and read `benchmarks/` + `scripts/` from it → verify: `bash scripts/run-ab-eval.sh --dry-run --runner-worktree | rg 'runner'`.
5. Record both worktree paths and SHAs in `inputs` → verify: `rg -n 'worktree' benchmarks/docs/SCHEMA-AB.md`.
6. Add a test that creates a branch in the subject, runs a dry-run, and asserts the branch is unchanged and the worktree is gone → verify: `bash tests/test_ab_worktree.sh`.

## Verification Script (Step-by-Step)

1. `git -C /tmp/bp-subject branch marker`; run a dry run; `git -C /tmp/bp-subject branch --show-current` is unchanged.
2. `git worktree list` in the subject has no leftover entry.
3. Send SIGINT during a run; the temp worktree is gone.
4. Dirty mode warns and records `dirty: true`.

## Out of scope

- Freezing the Docker image (the digest is recorded, not pulled).
- Freezing provider model weights (impossible; record the model ID).

## Risks

- `git worktree remove` fails if the worktree is dirty; use `--force` only on the temp path.
- A `trap` that calls `exit` can mask the original exit code; preserve `$?`.
- `rsync` may not be installed on a minimal macOS; fall back to `cp -R` and warn.

## Acceptance Criteria

- [ ] The subject is read from a detached worktree.
- [ ] The host branch is never mutated.
- [ ] Worktrees are removed on success, failure and SIGINT.
- [ ] Dirty mode is explicit and recorded.
