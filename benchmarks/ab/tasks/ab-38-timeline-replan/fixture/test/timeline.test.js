import test from "node:test";
import assert from "node:assert";
import { addDependency, addTask, baseline, createProject, replan, reset } from "../src/timeline.js";
test("baseline and replan return schedules", () => {
  reset();
  createProject({ id: "P1", name: "Launch" });
  addTask({ id: "A", projectId: "P1", estimateHours: 1 });
  addTask({ id: "B", projectId: "P1", estimateHours: 2 });
  addDependency({ taskId: "B", dependsOn: "A" });
  assert.strictEqual(baseline({ projectId: "P1" }).projectEnd, 3);
  assert.strictEqual(replan({ projectId: "P1" }).projectEnd, 3);
});
