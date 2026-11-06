import test from "node:test";
import assert from "node:assert";
import { addDependency, addTask, createProject, reset, schedule } from "../src/timeline.js";
test("schedules dependent tasks", () => {
  reset();
  createProject({ id: "P1", name: "Launch" });
  addTask({ id: "A", projectId: "P1", estimateHours: 1 });
  addTask({ id: "B", projectId: "P1", estimateHours: 2 });
  addDependency({ taskId: "B", dependsOn: "A" });
  assert.strictEqual(schedule({ projectId: "P1" }).projectEnd, 3);
});
