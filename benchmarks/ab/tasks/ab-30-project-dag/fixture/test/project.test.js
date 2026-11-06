import test from "node:test";
import assert from "node:assert";
import { addDependency, addTask, completeTask, projectDurationHours, reset, topologicalOrder } from "../src/project.js";

test("orders tasks after their dependencies", () => {
  reset();
  addTask({ id: "A", title: "A", estimateHours: 1 });
  addTask({ id: "B", title: "B", estimateHours: 2 });
  addDependency({ taskId: "B", dependsOn: "A" });
  assert.deepStrictEqual(topologicalOrder(), ["A", "B"]);
  assert.strictEqual(projectDurationHours(), 3);
  assert.strictEqual(completeTask("A").done, true);
});
