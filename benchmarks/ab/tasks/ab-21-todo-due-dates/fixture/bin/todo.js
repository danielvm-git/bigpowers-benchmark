#!/usr/bin/env node
import { loadState, saveState } from "../src/store.js";
import { addTodo, listTodos, completeTodo } from "../src/commands.js";

const file = process.env.TODO_FILE || "todos.json";
const [command, ...args] = process.argv.slice(2);
const state = loadState(file);

if (command === "add") {
  const text = args.join(" ");
  const todo = addTodo(state, text);
  saveState(file, state);
  console.log(JSON.stringify(todo));
} else if (command === "list") {
  for (const todo of listTodos(state)) {
    console.log(`${todo.done ? "x" : " "} ${todo.id} ${todo.text}`);
  }
} else if (command === "done") {
  const todo = completeTodo(state, Number(args[0]));
  saveState(file, state);
  console.log(JSON.stringify(todo));
} else {
  console.error("usage: todo add <text> | list | done <id>");
  process.exit(2);
}
