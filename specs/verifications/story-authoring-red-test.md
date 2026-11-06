# Story authoring rule — open with a red test

Status: in force from 2026-11-06.
Origin: adoption-readiness audit gate **F.28** ("first task of the first story is
a failing/characterization test written before code").

## The rule

Task 1 of every new story is a test that **fails before the implementation
exists**, or a characterization test that pins current behavior. Never a file
copy, a `test -f` presence check, or an inspection step.

Acceptable task-1 `verify:` commands exit non-zero on the pre-fix tree:

```yaml
# good — new behavior, fails today
- id: 1
  description: Add failing test that an infra crash is not scored as an agent failure
  verify: python3 Tests/test_ab_eval.py TestRunRecord.test_infra_error_is_not_agent_failure
  status: pending

# good — characterization of existing behavior before a refactor
- id: 1
  description: Pin current shard round-trip before touching the encoder
  verify: swift test --filter BenchRowCodingTests
  status: pending

# rejected — proves nothing about behavior
- id: 1
  verify: test -f specs/reports/latest.yaml
```

## Why this is recorded

The audit found two stories whose task 1 was not a test: `e01s01` opened with a
file copy and `e04s04` opened with a report presence check. Both shipped correct
code, so nothing regressed — but the plan gave no red step, which means the
"test first" claim was unverifiable for those stories.

## Current state

All 25 stories in `specs/epics/e01`–`e08` now verify green, so there is no
unbuilt story with a first task to make red. F.28 is therefore vacuous for the
existing plan and binding only for stories written from now on.

## Enforcement

`bash scripts/trace-stories.sh --strict` already requires every story to have a
`-tasks.yaml` with a runnable `verify:`. Reviewers should additionally confirm
that task 1 is a test command (`swift test`, `python3 Tests/...`, `bash
Tests/...`) rather than a filesystem assertion.
