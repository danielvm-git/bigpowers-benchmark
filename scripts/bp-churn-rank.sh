#!/usr/bin/env bash
# story: e10s01
# Rank repository files by git commit churn
set -euo pipefail

SINCE="90 days ago"
LIMIT=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE="${2//./ }"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "==> File Churn Ranking (since $SINCE, limit $LIMIT)"
git log --pretty=format: --name-only --since="$SINCE" 2>/dev/null | sed '/^$/d' | sort | uniq -c | sort -nr | head -n "$LIMIT"
