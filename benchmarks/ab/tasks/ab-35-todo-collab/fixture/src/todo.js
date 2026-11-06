const users = new Map();
const lists = new Map();
const tasks = new Map();
export function reset() { users.clear(); lists.clear(); tasks.clear(); }
export function createUser({ id, name }) { const u = { id, name }; users.set(id, u); return { ...u }; }
export function createList({ id, ownerId, name }) { const l = { id, ownerId, name, members: new Set() }; lists.set(id, l); return { id, ownerId, name }; }
export function shareList({ listId, userId }) { lists.get(listId).members.add(userId); }
export function createTask({ id, listId, title }) { const t = { id, listId, title, done: false }; tasks.set(id, t); return { ...t }; }
export function completeTask({ taskId }) { const t = tasks.get(taskId); t.done = true; return { ...t }; }
export function listTasks({ listId }) { return [...tasks.values()].filter((t) => t.listId === listId).map((t) => ({ ...t })); }
