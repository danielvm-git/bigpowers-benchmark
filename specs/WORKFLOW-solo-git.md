# Workflow: Solo Git Mode

## Overview
This repository uses the `solo-git` workflow mode.

## Policy
1. All changes are authored on feature branches (`feat/`, `fix/`, `chore/`).
2. Main is protected against direct pushes via local hooks (`guard-git`) and fast-forward rebases.
3. Tests and pre-commit checks must run green before merging to main.
4. Conventional Commits are enforced on all commit messages.
5. Linear git history is maintained.
