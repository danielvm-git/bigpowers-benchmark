function assertIsoDate(value, label) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(`invalid ${label}: ${value}`);
  }
  const parsed = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw new Error(`invalid ${label}: ${value}`);
  }
}

export function addTodo(state, text, { due = null } = {}) {
  if (due !== null) assertIsoDate(due, "due date");
  const todo = { id: state.nextId++, text, done: false, due };
  state.todos.push(todo);
  return { ...todo };
}

export function listTodos(state, { overdue = false, today = null } = {}) {
  if (overdue) assertIsoDate(today, "today");
  return state.todos
    .filter((todo) => !overdue || (!todo.done && todo.due !== null && todo.due < today))
    .map((todo) => ({ ...todo, due: todo.due ?? null }));
}

export function completeTodo(state, id) {
  const todo = state.todos.find((item) => item.id === id);
  if (!todo) throw new Error(`todo not found: ${id}`);
  todo.done = true;
  return { ...todo, due: todo.due ?? null };
}
