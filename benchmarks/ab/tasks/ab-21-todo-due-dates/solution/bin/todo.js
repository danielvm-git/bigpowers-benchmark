#!/usr/bin/env node
import { loadState, saveState } from "../src/store.js";
import { addTodo, listTodos, completeTodo } from "../src/commands.js";

const file = process.env.TODO_FILE || "todos.json";
const [command, ...args] = process.argv.slice(2);
const state = loadState(file);

function flag(name) {
  const index = args.indexOf(name);
  return index === -1 ? null : args[index + 1];
}

if (command === "add") {
  const due = flag("--due");
  const text = args.filter((arg, index) => !arg.startsWith("--") && args[index - 1] !== "--due").join(" ");
  const todo = addTodo(state, text, { due });
  saveState(file, state);
  console.log(JSON.stringify(todo));
} else if (command === "list") {
  const overdue = args.includes("--overdue");
  const today = flag("--today");
  const todos = listTodos(state, { overdue, today });
  if (args.includes("--json")) {
    console.log(JSON.stringify(todos, null, 2));
  } else {
    for (const todo of todos) {
      console.log(`${todo.done ? "x" : " "} ${todo.id} ${todo.text}${todo.due ? ` (due ${todo.due})` : ""}`);
    }
  }
} else if (command === "done") {
  const todo = completeTodo(state, Number(args[0]));
  saveState(file, state);
  console.log(JSON.stringify(todo));
} else {
  console.error("usage: todo add <text> [--due YYYY-MM-DD] | list [--overdue --today YYYY-MM-DD] [--json] | done <id>");
  process.exit(2);
}
