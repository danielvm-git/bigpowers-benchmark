import test from "node:test";
import assert from "node:assert";
import {
  addDependency, addTask, baseline, createProject, criticalPath, replan, reset,
} from "../src/timeline.js";

function setup() {
  reset();
  createProject({ id: "P1", name: "Launch" });
  addTask({ id: "A", projectId: "P1", estimateHours: 1 });
  addTask({ id: "B", projectId: "P1", estimateHours: 2 });
  addTask({ id: "C", projectId: "P1", estimateHours: 1 });
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "C", dependsOn: "A" });
}
function byId(rows, id) { return rows.find((row) => row.id === id); }

test("replanning reports slippage against an immutable baseline", () => {
  setup();
  const frozen = baseline({ projectId: "P1" });
  assert.strictEqual(frozen.projectEnd, 3);
  const result = replan({ projectId: "P1", delays: { A: 2 } });
  assert.deepStrictEqual(byId(result.tasks, "A"), { id: "A", start: 0, end: 3, slipHours: 2 });
  assert.deepStrictEqual(byId(result.tasks, "B"), { id: "B", start: 3, end: 5, slipHours: 2 });
  assert.strictEqual(result.projectEnd, 5);
  assert.strictEqual(result.slippedBy, 2);
  assert.deepStrictEqual(baseline({ projectId: "P1" }), frozen);
});

test("replanning changes the critical path when a branch slips", () => {
  setup();
  baseline({ projectId: "P1" });
  replan({ projectId: "P1", delays: { B: 5 } });
  assert.deepStrictEqual(criticalPath({ projectId: "P1" }), { path: ["A", "B"], durationHours: 8 });
});

test("baseline is required before replanning", () => {
  setup();
  assert.throws(() => replan({ projectId: "P1" }), { message: "baseline_required" });
});

test("replan validation", () => {
  setup();
  baseline({ projectId: "P1" });
  assert.throws(() => replan({ projectId: "P1", delays: { A: -1 } }),
    { message: "invalid_delay" });
  assert.throws(() => replan({ projectId: "P1", delays: { X: 1 } }),
    { message: "task_not_found: X" });
});

test("the schedule has every task exactly once", () => {
  setup();
  baseline({ projectId: "P1" });
  const result = replan({ projectId: "P1" });
  assert.deepStrictEqual(result.tasks.map((t) => t.id), ["A", "B", "C"]);
  assert.strictEqual(new Set(result.tasks.map((t) => t.id)).size, 3);
});

test("an empty project replans to zero", () => {
  reset();
  createProject({ id: "P1", name: "Empty" });
  assert.deepStrictEqual(baseline({ projectId: "P1" }), { tasks: [], projectEnd: 0 });
  assert.deepStrictEqual(replan({ projectId: "P1" }),
    { tasks: [], projectEnd: 0, slippedBy: 0 });
});
