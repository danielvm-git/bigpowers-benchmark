#!/usr/bin/env bash
# scripts/score_run.sh <worktree_path>
# Calculates scores for a benchmark run in a given worktree.

set -eo pipefail

WORKTREE_PATH="$1"

if [[ "$1" == "--help" || -z "$WORKTREE_PATH" ]]; then
  echo "Usage: scripts/score_run.sh <worktree_path>"
  echo "Calculates code_pass, artifact_score, convention_score, and token_cost."
  exit 0
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
  echo "Error: Worktree path '$WORKTREE_PATH' does not exist." >&2
  exit 1
fi

cd "$WORKTREE_PATH"

CODE_PASS=0
if [[ -f "test.js" ]] && node test.js >/dev/null 2>&1; then
  CODE_PASS=1
fi

MD_COUNT=0
if [[ -d "specs" ]]; then
  MD_COUNT=$(find specs -name "*.md" 2>/dev/null | wc -l | xargs)
fi
ARTIFACT_SCORE=0
if [[ "$MD_COUNT" -ge 3 ]]; then
  ARTIFACT_SCORE=2
elif [[ "$MD_COUNT" -ge 1 ]]; then
  ARTIFACT_SCORE=1
fi

CONVENTION_SCORE=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  COMMIT_COUNT=$(git log --oneline 2>/dev/null | wc -l | xargs || echo 0)
  if [[ "$COMMIT_COUNT" -gt 0 ]]; then
    if git log --format=%s 2>/dev/null | grep -Ei "^[a-z]+(\([a-z0-9_-]+\))?: .+" >/dev/null; then
      CONVENTION_SCORE=2
    else
      CONVENTION_SCORE=1
    fi
  fi
fi

TOKEN_COST=0
METRICS_FILE="runs/metrics.json"
if [[ -f "$METRICS_FILE" ]]; then
  TOKEN_COST=$(grep -o '"token_cost":[0-9.]*' "$METRICS_FILE" | cut -d: -f2 || echo 0)
fi

printf '{"code_pass":%d,"artifact_score":%d,"convention_score":%d,"token_cost":%s}\n' \
  "$CODE_PASS" "$ARTIFACT_SCORE" "$CONVENTION_SCORE" "$TOKEN_COST"
