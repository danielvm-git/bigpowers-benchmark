#!/usr/bin/env bash
# Run the A/B harness test suite. This repo has no bigpowers verification gates.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONHASHSEED=0 TZ=UTC LC_ALL=C

bash -n scripts/run-ab-eval.sh
bash -n scripts/ab-sandbox.sh
bash -n scripts/lib/ab-arm-bigpowers.sh
bash Tests/test_ab_worktree.sh

for test in \
  Tests/test_ab_eval.py \
  Tests/test_ab_ablation.py \
  Tests/test_ab_parity.py \
  Tests/test_ab_provenance.py \
  Tests/test_ab_process_group.py \
  Tests/test_ab_report_paths.py \
  Tests/test_ab_report.py \
  Tests/test_ab_decision.py \
  Tests/test_ab_calibration.py \
  Tests/test_task_quality.py \
  Tests/test_ab_preflight.py \
  Tests/test_ab_score.py \
  Tests/test_ab_tasks.py \
  Tests/test_ab_vsm.py \
  Tests/test_ab_waste.py \
  Tests/test_ab_lean.py \
  Tests/test_ab_progress.py \
  Tests/test_ab_sandbox.py \
  Tests/test_ab_pi.py
do
  echo "=== $test ==="
  python3 "$test"
done
