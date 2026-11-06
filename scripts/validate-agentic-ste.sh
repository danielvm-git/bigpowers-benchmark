#!/usr/bin/env bash
# story: e79s03
# Validate Agentic STE rules for instructions in markdown files
set -euo pipefail

STRICT=0
FILES=()

for arg in "$@"; do
  if [[ "$arg" == "--strict" ]]; then
    STRICT=1
  else
    FILES+=("$arg")
  fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: validate-agentic-ste.sh [--strict] <file1.md> [file2.md...]"
  exit 1
fi

ERRORS=0
for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Warning: File $file not found, skipping."
    continue
  fi
  # Verify directive keywords present (case insensitive)
  if ! grep -Eqi "\b(MUST|NEVER|ALWAYS|DO NOT)\b" "$file"; then
    echo "STE check: $file lacks directive keywords"
    ERRORS=$((ERRORS + 1))
  fi
done

if [[ "$ERRORS" -gt 0 && "$STRICT" -eq 1 ]]; then
  echo "Validation failed with $ERRORS error(s)."
  exit 1
fi

echo "Agentic STE validation passed for ${#FILES[@]} file(s)."
