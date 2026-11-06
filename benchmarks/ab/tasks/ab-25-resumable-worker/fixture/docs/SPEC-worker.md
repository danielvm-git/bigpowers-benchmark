# Specification: checkpointed resumable worker

## Overview

A deterministic worker processes a list of jobs and records its progress in a checkpoint file.
If the process stops, the next run resumes after the last completed job without repeating work.

## API

`runWorker({ jobs, checkpointPath, outputPath, worker, limit })`

- `jobs`: array of `{ id, ... }`.
- `worker`: `async (job) => result`.
- `limit`: maximum number of jobs to process in this run (default: all).
- Returns `{ processed, nextIndex }`.

## Behaviour

1. **Checkpoint shape.** `{ "version": 1, "nextIndex": number }`.
   A missing checkpoint starts at index 0. A checkpoint with any other version fails with
   `unsupported checkpoint version: <version>`. Malformed JSON fails with
   `invalid checkpoint: <path>`.
2. **Resume.** Start at `nextIndex`; jobs before it are never run again. The checkpoint is
   updated after **each** job, not only at the end.
3. **Atomic write.** The checkpoint is written to a temporary file in the same directory,
   flushed, and renamed over the old file. The old checkpoint is never truncated or left
   half-written. Temporary files are removed on failure.
4. **Output.** Each successful job appends one JSON line to `outputPath`:
   `{ "id": <job.id>, "result": <worker result> }`.
   A failed job appends nothing and does not advance the checkpoint; the error propagates.
5. **Lock.** A `<checkpointPath>.lock` file prevents two workers from running at once. If it
   exists, fail with `worker already running: <lockPath>`. The lock is removed on success and
   on failure.
6. **Limits.** `limit` may be `0`; a zero limit processes nothing and leaves the checkpoint
   unchanged (but still acquires and releases the lock).

## Invariants

- A resumed run never duplicates a completed job in the output.
- A failed run leaves the checkpoint at the last completed job.
- Existing tests in `test/worker.test.js` keep passing.
