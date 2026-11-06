import test from "node:test";
import assert from "node:assert";
import {
  addDependency, addTask, completeTask, projectDurationHours, progress, reset, topologicalOrder,
} from "../src/project.js";

function task(id, hours = 1) {
  addTask({ id, title: id, estimateHours: hours });
}

test("topological order is deterministic and dependencies come first", () => {
  reset();
  task("A"); task("B"); task("C"); task("D");
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "C", dependsOn: "A" });
  addDependency({ taskId: "D", dependsOn: "B" });
  addDependency({ taskId: "D", dependsOn: "C" });
  assert.deepStrictEqual(topologicalOrder(), ["A", "B", "C", "D"]);
});

test("direct and indirect cycles are rejected without changing the graph", () => {
  reset();
  task("A"); task("B"); task("C");
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "C", dependsOn: "B" });
  const before = topologicalOrder();
  assert.throws(() => addDependency({ taskId: "A", dependsOn: "C" }),
    { message: "cycle_detected" });
  assert.deepStrictEqual(topologicalOrder(), before);

  assert.throws(() => addDependency({ taskId: "A", dependsOn: "A" }),
    { message: "cycle_detected" });
});

test("duplicate dependencies are a no-op", () => {
  reset();
  task("A"); task("B");
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "B", dependsOn: "A" });
  assert.deepStrictEqual(topologicalOrder(), ["A", "B"]);
});

test("unknown tasks and duplicate ids are rejected", () => {
  reset();
  task("A");
  assert.throws(() => addDependency({ taskId: "B", dependsOn: "A" }),
    { message: "task_not_found: B" });
  assert.throws(() => addDependency({ taskId: "A", dependsOn: "B" }),
    { message: "task_not_found: B" });
  assert.throws(() => task("A"), { message: "duplicate_task: A" });
  assert.throws(() => addTask({ id: "B", title: "B", estimateHours: 0 }),
    { message: "invalid_estimate" });
});

test("project duration is the longest path, not the sum", () => {
  reset();
  task("A", 1); task("B", 2); task("C", 3); task("D", 4);
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "C", dependsOn: "A" });
  addDependency({ taskId: "D", dependsOn: "B" });
  addDependency({ taskId: "D", dependsOn: "C" });
  // A=1, B=3, C=4, D=8
  assert.strictEqual(projectDurationHours(), 8);
});

test("completion and progress use estimated hours", () => {
  reset();
  task("A", 1); task("B", 2);
  assert.deepStrictEqual(progress(), { completedHours: 0, totalHours: 3, percent: 0 });
  completeTask("A");
  assert.deepStrictEqual(progress(), { completedHours: 1, totalHours: 3, percent: 33.33 });
  completeTask("A");
  assert.deepStrictEqual(progress(), { completedHours: 1, totalHours: 3, percent: 33.33 });
  assert.throws(() => completeTask("X"), { message: "task_not_found: X" });
});

test("an empty project has no order, no duration and zero progress", () => {
  reset();
  assert.deepStrictEqual(topologicalOrder(), []);
  assert.strictEqual(projectDurationHours(), 0);
  assert.deepStrictEqual(progress(), { completedHours: 0, totalHours: 0, percent: 0 });
});
