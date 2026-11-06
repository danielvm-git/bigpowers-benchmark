# Test Plan — Epic e04 Task Discrimination

## 1. Scope & Objective
Validate that benchmark evaluation tasks discriminate reliably across models and agent arms, maintaining consistent difficulty classification.

## 2. Test Matrix & Risk-Scaled Levels
- **Unit / Contract Tests (L1 - Critical)**:
  - Verify mathematical score bands (`too_easy` > 0.8, `discriminating` 0.2–0.8, `too_hard` < 0.2).
  - Target: `Tests/test_ab_calibration.py`.
- **Integration / Harness Tests (L2 - High)**:
  - Verify calibration run execution, output YAML schemas, and caching behaviour.
  - Target: `Tests/test_ab_eval.py`.
- **Preflight & Fixture Tests (L3 - Critical)**:
  - Verify every discriminating task fails on pristine fixture and passes on reference solution.
  - Target: `scripts/run-ab-eval.sh --preflight-only`.
