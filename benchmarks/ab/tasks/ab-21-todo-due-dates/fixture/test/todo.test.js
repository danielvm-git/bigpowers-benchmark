import test from "node:test";
import assert from "node:assert";
import { addTodo, listTodos, completeTodo } from "../src/commands.js";

function state() {
  return { nextId: 1, todos: [] };
}

test("adds a todo and lists it", () => {
  const s = state();
  const todo = addTodo(s, "write tests");
  assert.strictEqual(todo.id, 1);
  assert.strictEqual(todo.done, false);
  assert.strictEqual(listTodos(s).length, 1);
});

test("completes a todo", () => {
  const s = state();
  addTodo(s, "ship it");
  assert.strictEqual(completeTodo(s, 1).done, true);
});

test("rejects an unknown id", () => {
  assert.throws(() => completeTodo(state(), 99), { message: "todo not found: 99" });
});
