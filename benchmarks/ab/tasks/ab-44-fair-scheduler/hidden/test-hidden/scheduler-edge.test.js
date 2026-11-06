import test from "node:test";
import assert from "node:assert";
import { runScheduler } from "../src/scheduler.js";

test("higher priority wins when no one ages", () => {
  const result = runScheduler([
    { id: "low", priority: 1, runtime: 1, arrival: 0 },
    { id: "high", priority: 5, runtime: 1, arrival: 0 },
  ]);
  assert.deepStrictEqual(result.order, ["high", "low"]);
});

test("aging promotes a long waiter above a higher base priority", () => {
  const result = runScheduler([
    { id: "slow", priority: 1, runtime: 2, arrival: 0 },
    { id: "fast", priority: 3, runtime: 1, arrival: 0 },
  ], { quantum: 1, agingAfter: 2 });
  assert.deepStrictEqual(result.order, ["fast", "slow"]);
});

test("quantum round-robins equal priorities", () => {
  const result = runScheduler([
    { id: "a", priority: 2, runtime: 2, arrival: 0 },
    { id: "b", priority: 2, runtime: 2, arrival: 0 },
  ], { quantum: 1, agingAfter: 100 });
  assert.deepStrictEqual(result.order, ["a", "b"]);
  assert.deepStrictEqual(result.completions, [{ id: "a", at: 2 }, { id: "b", at: 4 }]);
});

test("ties use arrival then id", () => {
  const result = runScheduler([
    { id: "z", priority: 2, runtime: 1, arrival: 0 },
    { id: "a", priority: 2, runtime: 1, arrival: 0 },
    { id: "later", priority: 5, runtime: 1, arrival: 0 },
  ]);
  assert.deepStrictEqual(result.order, ["later", "a", "z"]);
});

test("idle time advances to the next arrival", () => {
  const result = runScheduler([
    { id: "late", priority: 1, runtime: 1, arrival: 7 },
  ]);
  assert.deepStrictEqual(result.completions, [{ id: "late", at: 8 }]);
});

test("invalid jobs and duplicate ids fail", () => {
  assert.throws(() => runScheduler([{ id: "x", priority: 0, runtime: 1, arrival: 0 }]),
    { message: "invalid_job: x" });
  assert.throws(() => runScheduler([
    { id: "x", priority: 1, runtime: 1, arrival: 0 },
    { id: "x", priority: 2, runtime: 1, arrival: 0 },
  ]), { message: "duplicate_job: x" });
});
