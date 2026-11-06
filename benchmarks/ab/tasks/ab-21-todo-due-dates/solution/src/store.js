import fs from "node:fs";

function normalize(state) {
  const todos = Array.isArray(state.todos) ? state.todos : [];
  state.todos = todos.map((todo) => ({ ...todo, due: todo.due ?? null }));
  const maxId = state.todos.reduce((max, todo) => Math.max(max, todo.id || 0), 0);
  state.nextId = Math.max(Number(state.nextId) || 1, maxId + 1);
  return state;
}

export function loadState(file) {
  if (!fs.existsSync(file)) return { nextId: 1, todos: [] };
  return normalize(JSON.parse(fs.readFileSync(file, "utf8")));
}

export function saveState(file, state) {
  fs.writeFileSync(file, JSON.stringify(state, null, 2));
}
