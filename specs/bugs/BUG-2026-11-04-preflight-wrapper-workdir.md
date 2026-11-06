---
bug_id: BUG-2026-11-04-preflight-wrapper-workdir
status: fixed
severity: high
scope: benchmark preflight
title: "Containerized preflight graded the fixture, not the solution"
files_changed: "scripts/lib/ab_preflight.py, Tests/test_ab_preflight.py"
---

# BUG-2026-11-04: preflight solution check ignored the solution workdir

## Problem

The first real `pi-docker` calibration failed preflight for all four tasks:

```
[preflight] ab-09 FAIL
  - solution_passes_grade failed: exit=1
  - solution_score failed: exit=1
```

The same four tasks passed preflight on the host with `--adapter-cmd true`.

## Root Cause

`preflight_task` builds one environment with `AB_WORKDIR` pointing at the pristine fixture.
The `grade_wrapper` mounts `$AB_WORKDIR` into the container and runs the grade command there:

```
docker run ... -v "$AB_WORKDIR:/work" -w /work ...
```

When the solution copy was graded, the Python subprocess `cwd` was the solution directory but
`AB_WORKDIR` still named the fixture. The container therefore ran the hidden tests against the
unsolved fixture and reported failure. Host grading passed because it uses the subprocess cwd,
not `$AB_WORKDIR`.

## Fix

Use a per-workdir environment for the solution:

```python
solution_env = {**env, "AB_WORKDIR": str(solution)}
run(task["grade"], solution, solution_env, adapter)
run(task["score"], solution, solution_env, adapter)
```

`Tests/test_ab_preflight.py::test_grade_wrapper_runs_against_the_solution_workdir` adds a fake
wrapper that `cd`s to `$AB_WORKDIR`, which reproduces the bug without Docker.

## Evidence

- Real `pi-docker` preflight for `ab-09`, `ab-17`, `ab-19`, `ab-20`: all PASS.
- `python3 Tests/test_ab_preflight.py`: 8 tests OK.
- The calibration then started and completed round 1.
