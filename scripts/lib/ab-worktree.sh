#!/usr/bin/env bash
# Detached-worktree helpers for the A/B runner. Sourced, not executed.

ab_worktree_create() { # repo ref dir
  local repo="$1" ref="$2" dir="$3"
  mkdir -p "$dir"
  git -C "$repo" worktree add --detach "$dir" "$ref" >/dev/null 2>&1
}

ab_worktree_remove() { # repo dir
  local repo="$1" dir="$2"
  [ -n "$dir" ] || return 0
  git -C "$repo" worktree remove --force "$dir" >/dev/null 2>&1 || rm -rf "$dir"
}

ab_copy_tree() { # src dest (keeps .git so dirty state stays visible)
  local src="$1" dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude .build --exclude node_modules --exclude .venv "$src"/ "$dest"/
  else
    cp -R "$src"/. "$dest"/
  fi
}
