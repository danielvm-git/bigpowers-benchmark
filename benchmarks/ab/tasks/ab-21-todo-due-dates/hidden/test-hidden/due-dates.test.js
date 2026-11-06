import test from "node:test";
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { addTodo, listTodos, completeTodo } from "../src/commands.js";
import { loadState, saveState } from "../src/store.js";

function state() {
  return { nextId: 1, todos: [] };
}

test("stores an optional due date and keeps null when absent", () => {
  const s = state();
  assert.strictEqual(addTodo(s, "today", { due: "2026-11-04" }).due, "2026-11-04");
  assert.strictEqual(addTodo(s, "someday").due, null);
});

test("rejects invalid due dates", () => {
  const s = state();
  assert.throws(() => addTodo(s, "bad", { due: "2026-02-30" }), { message: /invalid due date/ });
  assert.throws(() => addTodo(s, "bad", { due: "12/01/2026" }), { message: /invalid due date/ });
});

test("overdue means incomplete, dated and strictly before today", () => {
  const s = state();
  addTodo(s, "late", { due: "2026-11-03" });
  addTodo(s, "today", { due: "2026-11-04" });
  addTodo(s, "tomorrow", { due: "2026-11-05" });
  addTodo(s, "undated");
  addTodo(s, "finished", { due: "2026-11-03" });
  completeTodo(s, 5);

  const overdue = listTodos(s, { overdue: true, today: "2026-11-04" });
  assert.deepStrictEqual(overdue.map((todo) => todo.text), ["late"]);
});

test("overdue requires a valid today", () => {
  assert.throws(() => listTodos(state(), { overdue: true, today: "not-a-date" }),
                { message: /invalid today/ });
  assert.throws(() => listTodos(state(), { overdue: true, today: null }),
                { message: /invalid today/ });
});

test("old files without due dates keep loading and gain a null due", () => {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "todo-")), "todos.json");
  fs.writeFileSync(file, JSON.stringify({
    nextId: 3,
    todos: [{ id: 1, text: "old", done: false }, { id: 2, text: "older", done: true }],
  }));
  const s = loadState(file);
  assert.strictEqual(s.todos.length, 2);
  assert.strictEqual(s.todos[0].due, null);
  assert.strictEqual(s.nextId, 3);

  addTodo(s, "new", { due: "2026-11-04" });
  saveState(file, s);
  const reloaded = loadState(file);
  assert.strictEqual(reloaded.todos.length, 3);
  assert.strictEqual(reloaded.todos[2].id, 3);
});

test("JSON output carries null or an ISO due date", () => {
  const s = state();
  addTodo(s, "dated", { due: "2026-11-04" });
  addTodo(s, "undated");
  const json = JSON.parse(JSON.stringify(listTodos(s)));
  assert.strictEqual(json[0].due, "2026-11-04");
  assert.strictEqual(json[1].due, null);
});

test("completing an unknown todo still fails", () => {
  assert.throws(() => completeTodo(state(), 42), { message: "todo not found: 42" });
});

test("regression: add, list and complete keep working", () => {
  const s = state();
  const todo = addTodo(s, "ship");
  assert.strictEqual(todo.due, null);
  assert.strictEqual(listTodos(s).length, 1);
  assert.strictEqual(completeTodo(s, 1).done, true);
});
