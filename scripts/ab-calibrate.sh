#!/usr/bin/env bash
# Vanilla-only calibration. Defaults to k=10; ab-eval.py owns the policy.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT/scripts/run-ab-eval.sh" --calibrate "$@"
