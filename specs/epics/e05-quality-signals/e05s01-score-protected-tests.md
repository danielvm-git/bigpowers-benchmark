# e05s01 — Score protected-test edits and penalize tampering
<!-- story: e05s01 -->

**type:** feature
**risk:** P0
**context:** harness
**BCPs:** 5

## Problem
An agent must not pass benchmarks by deleting, disabling, or modifying protected assertions.

## Verification
- `python3 Tests/test_ab_eval.py` tampering test cases pass.
