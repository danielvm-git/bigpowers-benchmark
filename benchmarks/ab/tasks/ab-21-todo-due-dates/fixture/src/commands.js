export function addTodo(state, text) {
  const todo = { id: state.nextId++, text, done: false };
  state.todos.push(todo);
  return { ...todo };
}

export function listTodos(state) {
  return state.todos.map((todo) => ({ ...todo }));
}

export function completeTodo(state, id) {
  const todo = state.todos.find((item) => item.id === id);
  if (!todo) throw new Error(`todo not found: ${id}`);
  todo.done = true;
  return { ...todo };
}
