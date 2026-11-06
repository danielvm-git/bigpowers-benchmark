# e02s04 — Remove duplicate report path and fix the e58 test flake
<!-- story: e02s04 -->

**type:** fix
**risk:** P1
**context:** infra
**BCPs:** 3

## Context

Two reliability defects undermine the benchmark's credibility:

1. **Duplicate report path.** `specs/benchmarks/ab/reports/AB-2026-11-03-k10-elite.yaml` duplicated
   the canonical `specs/benchmarks/reports/AB-2026-11-03-pi-docker-flash-k10-hard.*`. Two paths
   invite two truths.
2. **The e58 flake.** `python3 Tests/test_ab_eval.py` intermittently fails under CI contention
   after ~280 local reproduction attempts. The gate now prints the failing test name, but the root
   cause is still open.

This story both removes the ambiguity and hardens the test/runner against the most likely flake
mechanism: a timed-out `bash -c` that leaves grandchildren running and poisons a later test.

## Steps

1. Delete `benchmarks/ab/reports/`; standardize on `benchmarks/reports/`; add a test that the old
   path does not exist → verify: `test ! -d benchmarks/ab/reports && python3 Tests/test_ab_report_paths.py`.
2. Replace `subprocess.run(timeout=...)` in `ab-eval.py` with a `run_with_timeout` that starts a new
   session and kills the process group on timeout → verify: `python3 Tests/test_ab_process_group.py`.
3. Ensure no child survives a timeout: spawn a child that sleeps 300, time out after 1 s, assert the
   child is gone → verify: `python3 Tests/test_ab_process_group.py`.
4. Make the eval tests deterministic: `PYTHONHASHSEED=0`, `TZ=UTC`, `LC_ALL=C`, a per-class tmpdir,
   unique `sys.modules` names, and `timeout_s: 120` in fixtures → verify: `python3 Tests/test_ab_eval.py`.
5. Add a stress harness: `for i in $(seq 1 100); do python3 Tests/test_ab_eval.py || exit 1; done`
   under `--cpus=2` → verify: the loop exits 0.
6. Update `specs/bugs/BUG-2026-11-03-story-verify-e58-eval-flake.md` to `status: fixed` with the
   fixing commit and the stress evidence → verify: `rg -n 'status: fixed' specs/bugs/BUG-2026-11-03-story-verify-e58-eval-flake.md`.
7. Add both checks to the verification gate → verify: `rg -n 'test_ab_eval|test_ab_process_group|test_ab_report_paths' scripts/run-benchmark-tests.sh`.

## Verification Script (Step-by-Step)

1. `test ! -d benchmarks/ab/reports` succeeds.
2. `python3 Tests/test_ab_process_group.py` leaves no `sleep 300` process.
3. Run the eval suite 100 times; zero failures.
4. The bug file says fixed and links the commit.

## Out of scope

- Proving the flake root cause beyond the process-group hypothesis; if 100 runs still fail, keep the
  bug open with the named test and the new diagnostics.

## Risks

- Killing a process group can kill the test runner if the child shares the group; always
  `start_new_session=True`.
- `os.killpg` is POSIX-only; macOS and Linux CI are the targets, so that is acceptable.
- A stress loop is slow; run it nightly and in the story verification, not every commit.

## Acceptance Criteria

- [ ] Only one report path exists.
- [ ] A timed-out adapter leaves no child process.
- [ ] 100 consecutive eval-suite runs pass.
- [ ] The bug registry reflects the outcome honestly.
