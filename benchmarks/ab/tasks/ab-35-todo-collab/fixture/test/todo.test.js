import test from "node:test";
import assert from "node:assert";
import { createList, createTask, createUser, listTasks, reset } from "../src/todo.js";
test("creates a list and a task", () => {
  reset();
  createUser({ id: "U1", name: "Ana" });
  createList({ id: "L1", ownerId: "U1", name: "Work" });
  createTask({ id: "T1", listId: "L1", userId: "U1", title: "Ship" });
  assert.strictEqual(listTasks({ listId: "L1", userId: "U1" }).length, 1);
});
