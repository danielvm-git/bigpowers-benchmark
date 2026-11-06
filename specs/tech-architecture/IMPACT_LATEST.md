# Impact Assessment — Harness Port & Module Boundaries

## Affected Modules
- `BigPowersBenchmarkKit/Runner`: ShellCommandRunner and process streaming
- `benchmarks/ab/`: Task configurations, definitions, and schemas
- `scripts/`: Benchmark launch and calibration scripts

## Dependents & Blast Radius
1. **SwiftUI Desktop App**:
   - Consumes `BenchRow` JSON records written to `~/runs/data/`.
   - Ingests `ABRunRecord` reports for comparative score displays.
   - Blast radius: Isolated to views rendering benchmark output; no breaking schema changes introduced.
2. **Benchmark Runner Scripts**:
   - Backward-compatible arguments maintained in `scripts/run-ab-eval.sh`.
   - Calibration reports use standard `CALIBRATION-YYYY-MM-DD.yaml` format.

## Test Coverage
- Swift test suite: 179 tests across 54 suites covering runner, store, and UI models.
- Python test suite: 33 tests across `test_ab_eval.py` and `test_ab_score.py`.
