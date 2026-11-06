# Specification: timeline re-planning

## API

- `createProject({ id, name })`
- `addTask({ id, projectId, estimateHours })`
- `addDependency({ taskId, dependsOn })`
- `baseline({ projectId })`
- `replan({ projectId, delays = {} })`
- `criticalPath({ projectId })`
- `reset()`

## Rules

1. **Baseline.** `baseline` freezes the current schedule. A second call returns the same baseline
   without changing it. `replan` before a baseline fails with `baseline_required`.
2. **Schedule.** Finish-to-start; a task starts at the max end of its dependencies and ends at
   `start + estimate + delay`. Ties are ordered by task id. An empty project ends at 0.
3. **Replan.** `delays` maps task ids to non-negative integer hours added to the task's duration.
   Replanning returns the new schedule and, per task, `slipHours` compared with the baseline.
   `slippedBy` is the project-end difference.
4. **Critical path.** `criticalPath` returns `{ path, durationHours }` for the longest path after
   the current delays; ties break by task id.
5. **Errors.** Unknown project/task, negative delay, cycle, cross-project edge: use the same
   messages as the timeline task (`project_not_found: <id>`, `task_not_found: <id>`,
   `invalid_delay`, `cycle_detected`, `cross_project_dependency`).

## Invariants

- Existing tests in `test/timeline.test.js` keep passing.
- The baseline is immutable after it is taken.
