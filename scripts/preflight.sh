#!/usr/bin/env bash
# story: e10s01
# BigPowers-Benchmark Preflight script
set -euo pipefail

echo "==> Running BigPowers-Benchmark Preflight"
swift test

# Resolve lefthook from PATH or the Node devDependency install, so CI matches
# a local Homebrew install. Missing lefthook is a skip, never a failure.
lefthook_bin=""
if command -v lefthook >/dev/null 2>&1; then
  lefthook_bin="lefthook"
elif [ -x node_modules/.bin/lefthook ]; then
  lefthook_bin="node_modules/.bin/lefthook"
fi

if [ -n "$lefthook_bin" ]; then
  "$lefthook_bin" run pre-commit
else
  echo "[preflight] lefthook not found — skipping lint hooks" >&2
fi

swift build
echo "==> Preflight PASS"
