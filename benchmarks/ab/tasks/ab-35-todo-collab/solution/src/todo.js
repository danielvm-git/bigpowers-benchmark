const users = new Map();
const lists = new Map();
const tasks = new Map();
export function reset() { users.clear(); lists.clear(); tasks.clear(); }
function fail(code) { throw new Error(code); }
function requireUser(id) { if (!users.has(id)) fail(`user_not_found: ${id}`); }
function requireList(id) { const l = lists.get(id); if (!l) fail(`list_not_found: ${id}`); return l; }
function isMember(list, userId) { return list.ownerId === userId || list.members.has(userId); }
function requireMember(list, userId) { if (!isMember(list, userId)) fail("not_list_member"); }
function requireOwner(list, userId) { if (list.ownerId !== userId) fail("not_list_owner"); }

export function createUser({ id, name }) {
  if (typeof id !== "string" || !id) fail("invalid_user_id");
  if (users.has(id)) fail(`duplicate_user: ${id}`);
  const user = { id, name }; users.set(id, user); return { ...user };
}
export function createList({ id, ownerId, name }) {
  requireUser(ownerId);
  if (typeof id !== "string" || !id) fail("invalid_list_id");
  if (lists.has(id)) fail(`duplicate_list: ${id}`);
  const list = { id, ownerId, name, members: new Set() }; lists.set(id, list);
  return { id, ownerId, name };
}
export function shareList({ listId, ownerId, userId }) {
  const list = requireList(listId); requireOwner(list, ownerId); requireUser(userId);
  if (userId !== list.ownerId) list.members.add(userId);
  return { listId, members: [list.ownerId, ...list.members] };
}
export function createTask({ id, listId, userId, title }) {
  const list = requireList(listId); requireMember(list, userId);
  if (typeof id !== "string" || !id) fail("invalid_task_id");
  if (tasks.has(id)) fail(`duplicate_task: ${id}`);
  if (typeof title !== "string" || !title.trim()) fail("invalid_title");
  const task = { id, listId, title, done: false }; tasks.set(id, task); return { ...task };
}
export function completeTask({ taskId, userId }) {
  const task = tasks.get(taskId);
  if (!task) fail(`task_not_found: ${taskId}`);
  const list = requireList(task.listId); requireMember(list, userId);
  task.done = true; return { ...task };
}
export function listTasks({ listId, userId }) {
  const list = requireList(listId); requireMember(list, userId);
  return [...tasks.values()].filter((t) => t.listId === listId).map((t) => ({ ...t }));
}
export function transferOwnership({ listId, ownerId, newOwnerId }) {
  const list = requireList(listId); requireOwner(list, ownerId); requireUser(newOwnerId);
  if (!list.members.has(newOwnerId)) fail("not_list_member");
  list.members.delete(newOwnerId);
  list.members.add(ownerId);
  list.ownerId = newOwnerId;
  return { listId, ownerId: newOwnerId, members: [newOwnerId, ...list.members] };
}
