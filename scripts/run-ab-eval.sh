#!/usr/bin/env bash
# story: e58s01 e02s03
# run-ab-eval.sh — run the same tasks with and without bigpowers; grade only the outcome.
# Advisory: exits 0 after a completed run, 2 on configuration errors.
# See benchmarks/docs/SCHEMA-AB.md.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AB_RUNNER_ROOT="${AB_RUNNER_ROOT:-$ROOT}"
export AB_RUNNER_SOURCE_ROOT="${AB_RUNNER_SOURCE_ROOT:-$ROOT}"
source "$(dirname "${BASH_SOURCE[0]}")/lib/python-env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/ab-worktree.sh"

ARGS=("$@")
SUBJECT=""
ALLOW_DIRTY=0
DRY_RUN=0
PREFLIGHT_ONLY=0
VERIFY_INPUTS=""
RUNNER_WORKTREE=0

for ((i = 0; i < ${#ARGS[@]}; i++)); do
  case "${ARGS[$i]}" in
    --bigpowers-root)
      SUBJECT="${ARGS[$((i + 1))]:-}"
      i=$((i + 1))
      ;;
    --bigpowers-root=*) SUBJECT="${ARGS[$i]#*=}" ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --preflight-only) PREFLIGHT_ONLY=1 ;;
    --verify-inputs)
      VERIFY_INPUTS="${ARGS[$((i + 1))]:-}"
      i=$((i + 1))
      ;;
    --runner-worktree) RUNNER_WORKTREE=1 ;;
  esac
done

WT_REPO=()
WT_DIR=()
TEMP_DIRS=()

cleanup() {
  local i
  for i in "${!WT_DIR[@]}"; do
    ab_worktree_remove "${WT_REPO[$i]}" "${WT_DIR[$i]}"
  done
  for i in "${!TEMP_DIRS[@]}"; do
    rm -rf "${TEMP_DIRS[$i]}"
  done
}
trap cleanup EXIT INT TERM

SUBJECT_RUN="$SUBJECT"
if [[ -n "$SUBJECT" && -z "$VERIFY_INPUTS" && "$DRY_RUN" -eq 0 ]]; then
  SUBJECT="$(cd "$SUBJECT" && pwd -P)"
  export AB_BP_SOURCE_ROOT="$SUBJECT"

  if git -C "$SUBJECT" rev-parse --git-dir >/dev/null 2>&1; then
    DIRTY="$(git -C "$SUBJECT" status --porcelain)"
    if [[ -n "$DIRTY" && "$ALLOW_DIRTY" -eq 0 ]]; then
      echo "ERROR: bigpowers checkout is dirty; commit/stash or pass --allow-dirty" >&2
      exit 2
    fi
    if [[ -n "$DIRTY" ]]; then
      echo "WARNING: --allow-dirty copies the working tree instead of using HEAD" >&2
      COPY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bp-subject-XXXXXX")"
      TEMP_DIRS+=("$COPY_DIR")
      ab_copy_tree "$SUBJECT" "$COPY_DIR"
      SUBJECT_RUN="$COPY_DIR"
    else
      WT_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bp-worktree-XXXXXX")"
      WT_DIR+=("$WT_ROOT/subject")
      WT_REPO+=("$SUBJECT")
      ab_worktree_create "$SUBJECT" HEAD "$WT_ROOT/subject"
      SUBJECT_RUN="$WT_ROOT/subject"
    fi
  else
    echo "WARNING: $SUBJECT is not a git checkout; running in place" >&2
  fi
fi

if [[ "$RUNNER_WORKTREE" -eq 1 ]]; then
  RUNNER_WT="$(mktemp -d "${TMPDIR:-/tmp}/bp-runner-XXXXXX")/runner"
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 &&
     [[ -z "$(git -C "$ROOT" status --porcelain)" ]]; then
    WT_DIR+=("$RUNNER_WT")
    WT_REPO+=("$ROOT")
    ab_worktree_create "$ROOT" HEAD "$RUNNER_WT"
  else
    echo "WARNING: runner checkout is not clean; copying it instead of a worktree" >&2
    TEMP_DIRS+=("$(dirname "$RUNNER_WT")")
    ab_copy_tree "$ROOT" "$RUNNER_WT"
  fi
  export AB_RUNNER_ROOT="$RUNNER_WT"
  export AB_RUNNER_SOURCE_ROOT="$ROOT"
fi

NEW_ARGS=()
for ((i = 0; i < ${#ARGS[@]}; i++)); do
  case "${ARGS[$i]}" in
    --bigpowers-root)
      NEW_ARGS+=("--bigpowers-root" "$SUBJECT_RUN")
      i=$((i + 1))
      ;;
    --bigpowers-root=*) NEW_ARGS+=("--bigpowers-root=$SUBJECT_RUN") ;;
    --runner-worktree) ;;
    *) NEW_ARGS+=("${ARGS[$i]}") ;;
  esac
done

set +e
"$PYTHON" "$ROOT/scripts/lib/ab-eval.py" "${NEW_ARGS[@]}"
STATUS=$?
set -e
exit "$STATUS"
