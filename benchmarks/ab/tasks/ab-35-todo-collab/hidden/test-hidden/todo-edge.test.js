import test from "node:test";
import assert from "node:assert";
import {
  completeTask, createList, createTask, createUser, listTasks, reset, shareList, transferOwnership,
} from "../src/todo.js";

function setup() {
  reset();
  createUser({ id: "U1", name: "Ana" });
  createUser({ id: "U2", name: "Bruno" });
  createUser({ id: "U3", name: "Carla" });
  createList({ id: "L1", ownerId: "U1", name: "Work" });
}

test("sharing grants a member access to the list", () => {
  setup();
  shareList({ listId: "L1", ownerId: "U1", userId: "U2" });
  createTask({ id: "T1", listId: "L1", userId: "U2", title: "Shared task" });
  assert.deepStrictEqual(listTasks({ listId: "L1", userId: "U2" }).map((t) => t.id), ["T1"]);
  assert.strictEqual(completeTask({ taskId: "T1", userId: "U2" }).done, true);
});

test("non-members cannot create, list or complete tasks", () => {
  setup();
  shareList({ listId: "L1", ownerId: "U1", userId: "U2" });
  createTask({ id: "T1", listId: "L1", userId: "U1", title: "Task" });
  assert.throws(() => createTask({ id: "T2", listId: "L1", userId: "U3", title: "No" }),
    { message: "not_list_member" });
  assert.throws(() => listTasks({ listId: "L1", userId: "U3" }), { message: "not_list_member" });
  assert.throws(() => completeTask({ taskId: "T1", userId: "U3" }),
    { message: "not_list_member" });
});

test("only the owner can share and duplicate shares are no-ops", () => {
  setup();
  shareList({ listId: "L1", ownerId: "U1", userId: "U2" });
  shareList({ listId: "L1", ownerId: "U1", userId: "U2" });
  assert.strictEqual(listTasks({ listId: "L1", userId: "U2" }).length, 0);
  assert.throws(() => shareList({ listId: "L1", ownerId: "U2", userId: "U3" }),
    { message: "not_list_owner" });
});

test("completion is idempotent and preserves task order", () => {
  setup();
  createTask({ id: "T1", listId: "L1", userId: "U1", title: "One" });
  createTask({ id: "T2", listId: "L1", userId: "U1", title: "Two" });
  completeTask({ taskId: "T1", userId: "U1" });
  completeTask({ taskId: "T1", userId: "U1" });
  assert.deepStrictEqual(listTasks({ listId: "L1", userId: "U1" }).map((t) => t.id), ["T1", "T2"]);
});

test("ownership transfer changes permissions and keeps the old owner as a member", () => {
  setup();
  shareList({ listId: "L1", ownerId: "U1", userId: "U2" });
  transferOwnership({ listId: "L1", ownerId: "U1", newOwnerId: "U2" });
  createTask({ id: "T1", listId: "L1", userId: "U2", title: "New owner" });
  assert.strictEqual(listTasks({ listId: "L1", userId: "U1" }).length, 1);
  assert.throws(() => transferOwnership({ listId: "L1", ownerId: "U1", newOwnerId: "U3" }),
    { message: "not_list_owner" });
});

test("unknown ids and validation", () => {
  setup();
  assert.throws(() => createList({ id: "L2", ownerId: "X", name: "X" }),
    { message: "user_not_found: X" });
  assert.throws(() => shareList({ listId: "X", ownerId: "U1", userId: "U2" }),
    { message: "list_not_found: X" });
  assert.throws(() => createTask({ id: "T1", listId: "L1", userId: "U1", title: "" }),
    { message: "invalid_title" });
  createTask({ id: "T1", listId: "L1", userId: "U1", title: "One" });
  assert.throws(() => completeTask({ taskId: "X", userId: "U1" }),
    { message: "task_not_found: X" });
});
