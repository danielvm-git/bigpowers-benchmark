#!/usr/bin/env bash
# story: e10s01
# Trace story tags across specs, code, and tests
set -euo pipefail

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

COUNT=$(grep -rn "story: e" specs/ Sources/ Tests/ scripts/ 2>/dev/null | wc -l | tr -d ' ')
echo "Found $COUNT story tags across repository."

if [[ "$STRICT" -eq 1 && "$COUNT" -eq 0 ]]; then
  echo "ERROR: No story tags found under --strict mode." >&2
  exit 1
fi
