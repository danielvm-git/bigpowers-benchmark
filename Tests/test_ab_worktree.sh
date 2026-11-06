#!/usr/bin/env bash
# tests/test_ab_worktree.sh — the subject snapshot must not move when the host repo moves.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/ab-worktree.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/bp-wt-test-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q repo
git -C "$TMP/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
echo "original" > "$TMP/repo/file.txt"
git -C "$TMP/repo" add file.txt
git -C "$TMP/repo" -c user.name=t -c user.email=t@t commit -q -m file

ab_worktree_create "$TMP/repo" HEAD "$TMP/subject"
test -f "$TMP/subject/file.txt"
grep -q original "$TMP/subject/file.txt"

# Move the host repo: a new branch, a commit, and a changed file.
git -C "$TMP/repo" checkout -q -b feature
echo "changed" > "$TMP/repo/file.txt"
git -C "$TMP/repo" -c user.name=t -c user.email=t@t commit -q -am change
grep -q original "$TMP/subject/file.txt"
! grep -q changed "$TMP/subject/file.txt"

# The runner worktree sees only the committed HEAD at creation time.
ab_worktree_create "$TMP/repo" HEAD "$TMP/runner"
grep -q changed "$TMP/runner/file.txt"

ab_worktree_remove "$TMP/repo" "$TMP/subject"
test ! -d "$TMP/subject"
! git -C "$TMP/repo" worktree list | grep -q "$TMP/subject"

# Dirty copies keep .git so provenance can still see the dirty state.
mkdir -p "$TMP/dirty"
ab_copy_tree "$TMP/repo" "$TMP/dirty"
test -d "$TMP/dirty/.git"
test -f "$TMP/dirty/file.txt"

echo "worktree: PASS"
