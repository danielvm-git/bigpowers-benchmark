---
bug_id: BUG-2026-11-03-story-verify-e58-eval-flake
status: fixed
severity: high
scope: benchmark runner / tests
title: "test_ab_eval.py flakes under CI contention and leaves no failing test name"
files_changed: "scripts/lib/ab_process.py, scripts/lib/ab-eval.py, Tests/test_ab_eval.py"
---

# BUG-2026-11-03: intermittent test_ab_eval failure

## Problem

`python3 Tests/test_ab_eval.py` intermittently failed on a clean tree under CI contention.
The original bigpowers gate printed only the last three lines, so the failing test was unnamed.
The same tree passed minutes earlier and 280 local attempts did not reproduce it.

## Root Cause

The runner used `subprocess.run(..., timeout=...)`. On timeout Python kills the direct child
(`bash`) but not its process group. A timed-out `bash -c` can leave a `node`/`sleep` grandchild
alive; that orphan then competes with later tests, and the shared pipe/line buffer sees
interleaved output. The symptom matches the observed range trap and unnamed assertion failure.

## Fix

`scripts/lib/ab_process.py` replaces the direct `subprocess.run`:

- `Popen(..., start_new_session=True)` puts the command in its own process group.
- On `TimeoutExpired`, `os.killpg(os.getpgid(pid), SIGKILL)` kills the whole group.
- `communicate()` then reaps the pipes before `TimeoutExpired` is re-raised with output.

`ab-eval.py` and `ab_preflight.py` both route through it.

The test harness also pins `PYTHONHASHSEED=0`, `TZ=UTC`, `LC_ALL=C`, and raises the fake task
timeout from 30 s to 120 s so CI contention cannot look like a product failure.

## Evidence

- `Tests/test_ab_process_group.py`: a command that spawns `sleep 300` times out after 1 s; the
  grandchild PID is gone afterwards.
- 100 concurrent runs of `Tests/test_ab_eval.py` at `-P 6`: **100/100 passed, 0 failures**.
- The full benchmark gate (`bash scripts/run-benchmark-tests.sh`) passes.

## Follow-up

The stress run is the reproduction protocol. If this recurs, capture the failing test name and
the process list at the moment of failure; do not re-open with a speculative patch.
