# Specification: project DAG

## Overview

An in-memory project graph: tasks, dependencies, a deterministic topological order, the longest
path duration and completion progress.

## API

- `addTask({ id, title, estimateHours = 1 })`
- `addDependency({ taskId, dependsOn })`
- `completeTask(id)`
- `topologicalOrder()`
- `projectDurationHours()`
- `progress()`
- `reset()`

## Rules

1. **Tasks.** `id` is unique and non-empty; `estimateHours` is a positive integer.
   A duplicate id fails with `duplicate_task: <id>`; an invalid estimate fails with
   `invalid_estimate`; an invalid id with `invalid_task_id`.
2. **Dependencies.** Both tasks must exist; a task cannot depend on itself; an existing edge is a
   no-op. Adding an edge that creates a cycle fails with `cycle_detected` and changes nothing.
3. **Order.** `topologicalOrder()` returns every task exactly once, with dependencies before
   dependants. Ties are broken by task id ascending.
4. **Duration.** `projectDurationHours()` is the longest dependency path by estimate hours.
   An empty project is 0.
5. **Completion.** `completeTask(id)` is idempotent; an unknown id fails with
   `task_not_found: <id>`.
6. **Progress.** `progress()` returns
   `{ completedHours, totalHours, percent }`, where `percent` is
   `completedHours / totalHours * 100` rounded to two decimals, or 0 for an empty project.

## Invariants

- A rejected dependency never mutates the graph.
- Existing tests in `test/project.test.js` keep passing.
