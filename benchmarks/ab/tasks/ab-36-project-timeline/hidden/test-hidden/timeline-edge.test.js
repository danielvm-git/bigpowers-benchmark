import test from "node:test";
import assert from "node:assert";
import {
  addDependency, addTask, createProject, criticalPath, delayTask, reset, schedule,
} from "../src/timeline.js";

function setup() {
  reset();
  createProject({ id: "P1", name: "Launch" });
  addTask({ id: "A", projectId: "P1", estimateHours: 1 });
  addTask({ id: "B", projectId: "P1", estimateHours: 2 });
  addTask({ id: "C", projectId: "P1", estimateHours: 3 });
}
function byId(rows, id) { return rows.find((row) => row.id === id); }

test("parallel branches start after their dependency", () => {
  setup();
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "C", dependsOn: "A" });
  const result = schedule({ projectId: "P1" });
  assert.deepStrictEqual(byId(result.tasks, "A"), { id: "A", start: 0, end: 1 });
  assert.deepStrictEqual(byId(result.tasks, "B"), { id: "B", start: 1, end: 3 });
  assert.deepStrictEqual(byId(result.tasks, "C"), { id: "C", start: 1, end: 4 });
  assert.strictEqual(result.projectEnd, 4);
});

test("delays shift the task and its dependants", () => {
  setup();
  addDependency({ taskId: "B", dependsOn: "A" });
  delayTask({ taskId: "A", hours: 2 });
  const result = schedule({ projectId: "P1" });
  assert.deepStrictEqual(byId(result.tasks, "A"), { id: "A", start: 0, end: 3 });
  assert.deepStrictEqual(byId(result.tasks, "B"), { id: "B", start: 3, end: 5 });
  assert.strictEqual(result.projectEnd, 5);
});

test("cycles are rejected without changing the schedule", () => {
  setup();
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "C", dependsOn: "B" });
  const before = schedule({ projectId: "P1" });
  assert.throws(() => addDependency({ taskId: "A", dependsOn: "C" }),
    { message: "cycle_detected" });
  assert.deepStrictEqual(schedule({ projectId: "P1" }), before);
  assert.throws(() => addDependency({ taskId: "A", dependsOn: "A" }),
    { message: "cycle_detected" });
});

test("duplicate dependencies are a no-op", () => {
  setup();
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "B", dependsOn: "A" });
  assert.deepStrictEqual(byId(schedule({ projectId: "P1" }).tasks, "B"),
    { id: "B", start: 1, end: 3 });
});

test("critical path picks the longest branch", () => {
  reset();
  createProject({ id: "P1", name: "Launch" });
  addTask({ id: "A", projectId: "P1", estimateHours: 1 });
  addTask({ id: "B", projectId: "P1", estimateHours: 2 });
  addTask({ id: "C", projectId: "P1", estimateHours: 5 });
  addTask({ id: "D", projectId: "P1", estimateHours: 1 });
  addDependency({ taskId: "B", dependsOn: "A" });
  addDependency({ taskId: "C", dependsOn: "A" });
  addDependency({ taskId: "D", dependsOn: "B" });
  assert.deepStrictEqual(criticalPath({ projectId: "P1" }),
    { path: ["A", "C"], durationHours: 6 });
});

test("unknown ids, cross-project edges and validation", () => {
  setup();
  createProject({ id: "P2", name: "Other" });
  addTask({ id: "Z", projectId: "P2", estimateHours: 1 });
  assert.throws(() => addTask({ id: "X", projectId: "X", estimateHours: 1 }),
    { message: "project_not_found: X" });
  assert.throws(() => addDependency({ taskId: "A", dependsOn: "X" }),
    { message: "task_not_found: X" });
  assert.throws(() => addDependency({ taskId: "A", dependsOn: "Z" }),
    { message: "cross_project_dependency" });
  assert.throws(() => delayTask({ taskId: "A", hours: -1 }), { message: "invalid_delay" });
  assert.throws(() => addTask({ id: "A", projectId: "P1", estimateHours: 1 }),
    { message: "duplicate_task: A" });
});

test("an empty project has no schedule and no critical path", () => {
  reset();
  createProject({ id: "P1", name: "Empty" });
  assert.deepStrictEqual(schedule({ projectId: "P1" }), { tasks: [], projectEnd: 0 });
  assert.deepStrictEqual(criticalPath({ projectId: "P1" }), { path: [], durationHours: 0 });
});
