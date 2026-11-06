import test from "node:test";
import assert from "node:assert";
import { runScheduler } from "../src/scheduler.js";

test("higher priority runs first", () => {
  const result = runScheduler([
    { id: "low", priority: 1, runtime: 1, arrival: 0 },
    { id: "high", priority: 5, runtime: 1, arrival: 0 },
  ]);
  assert.deepStrictEqual(result.order, ["high", "low"]);
});
