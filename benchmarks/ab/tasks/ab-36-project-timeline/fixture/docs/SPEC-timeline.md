# Specification: project timeline

## API

- `createProject({ id, name })`
- `addTask({ id, projectId, estimateHours })`
- `addDependency({ taskId, dependsOn })`
- `delayTask({ taskId, hours })`
- `schedule({ projectId })`
- `criticalPath({ projectId })`
- `reset()`

## Rules

1. **Tasks.** Unique id, existing project, positive integer estimate. An unknown project fails
   with `project_not_found: <id>`; an unknown task with `task_not_found: <id>`.
2. **Dependencies.** Both tasks exist; no self-dependency; duplicate edge is a no-op; a cycle
   fails with `cycle_detected` and changes nothing; tasks from different projects fail with
   `cross_project_dependency`.
3. **Schedule.** Finish-to-start: a task starts at the maximum end of its dependencies (0 if none)
   and ends at `start + estimateHours + delay`. `schedule` returns tasks in deterministic
   topological order (ties by id) and `projectEnd` is the maximum end. An empty project is 0.
4. **Delay.** `delayTask({ taskId, hours })` adds non-negative integer hours to that task's duration;
   dependants shift accordingly. A negative or non-integer value fails with `invalid_delay`.
5. **Critical path.** `criticalPath` returns `{ path, durationHours }` for one longest path, with
   ties broken by task id at each choice.

## Invariants

- Existing tests in `test/timeline.test.js` keep passing.
- A rejected dependency never changes the schedule.
