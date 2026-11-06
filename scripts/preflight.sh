#!/usr/bin/env bash
# story: e10s01
# BigPowers-Benchmark Preflight script
set -euo pipefail

echo "==> Running BigPowers-Benchmark Preflight"
swift test
if command -v lefthook >/dev/null 2>&1; then
  lefthook run pre-commit
elif command -v npx >/dev/null 2>&1; then
  npx --no-install lefthook run pre-commit
fi
swift build
echo "==> Preflight PASS"
