# Specification: fair job scheduler

## API

`runScheduler(jobs, config)` returns `{ order, completions }`.

- `jobs`: `{ id, priority, runtime, arrival }`.
  `priority` is an integer 1–5 (higher wins), `runtime` is a positive integer number of
  steps, and `arrival` is a non-negative integer start time. Ids are unique.
- `config`: `{ quantum = 2, agingAfter = 2 }`; both are positive integers.

## Rules

1. **Ready set.** A job is ready when `arrival <= time` and it has steps left.
2. **Effective priority.** `priority + floor((time - lastRunAt) / agingAfter)`, where
   `lastRunAt` starts at `arrival` and is set to `time` after each slice.
3. **Choice.** Run the highest effective priority. Break ties by earliest `arrival`, then
   lexicographic `id`.
4. **Slice.** Run `min(quantum, remaining)` steps. Advance `time` by the slice and reduce
   `remaining`. A completed job records `{ id, at }` in completion order.
5. **Idle.** If no job is ready and some have not arrived, advance `time` to the next arrival.
6. **Validation.** Duplicate ids fail with `duplicate_job: <id>`; invalid jobs fail with
   `invalid_job: <id>`; invalid config fails with `invalid_config`.

## Invariants

- Existing tests in `test/scheduler.test.js` keep passing.
- Every job completes exactly once and `order` matches `completions`.
