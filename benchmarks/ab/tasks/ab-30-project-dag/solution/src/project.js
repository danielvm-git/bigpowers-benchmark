const tasks = new Map();
const dependencies = new Map();

export function reset() {
  tasks.clear();
  dependencies.clear();
}

function fail(code) {
  throw new Error(code);
}

function requireTask(id) {
  const task = tasks.get(id);
  if (!task) fail(`task_not_found: ${id}`);
  return task;
}

export function addTask({ id, title, estimateHours = 1 }) {
  if (typeof id !== "string" || !id) fail("invalid_task_id");
  if (tasks.has(id)) fail(`duplicate_task: ${id}`);
  if (!Number.isInteger(estimateHours) || estimateHours <= 0) fail("invalid_estimate");
  const task = { id, title, estimateHours, done: false };
  tasks.set(id, task);
  dependencies.set(id, new Set());
  return { ...task };
}

function reaches(from, target) {
  const seen = new Set();
  const stack = [from];
  while (stack.length) {
    const current = stack.pop();
    if (current === target) return true;
    if (seen.has(current)) continue;
    seen.add(current);
    for (const next of dependencies.get(current) ?? []) stack.push(next);
  }
  return false;
}

export function addDependency({ taskId, dependsOn }) {
  requireTask(taskId);
  requireTask(dependsOn);
  if (taskId === dependsOn) fail("cycle_detected");
  if (dependencies.get(taskId).has(dependsOn)) return;
  if (reaches(dependsOn, taskId)) fail("cycle_detected");
  dependencies.get(taskId).add(dependsOn);
}

export function completeTask(id) {
  const task = requireTask(id);
  task.done = true;
  return { ...task };
}

export function topologicalOrder() {
  const indegree = new Map([...tasks.keys()].map((id) => [id, 0]));
  const dependants = new Map([...tasks.keys()].map((id) => [id, []]));
  for (const [taskId, deps] of dependencies) {
    indegree.set(taskId, deps.size);
    for (const dep of deps) dependants.get(dep).push(taskId);
  }
  const ready = [...indegree.entries()]
    .filter(([, count]) => count === 0)
    .map(([id]) => id)
    .sort();
  const order = [];
  while (ready.length) {
    const id = ready.shift();
    order.push(id);
    for (const next of dependants.get(id)) {
      indegree.set(next, indegree.get(next) - 1);
      if (indegree.get(next) === 0) {
        ready.push(next);
        ready.sort();
      }
    }
  }
  if (order.length !== tasks.size) fail("cycle_detected");
  return order;
}

export function projectDurationHours() {
  const memo = new Map();
  function duration(id) {
    if (memo.has(id)) return memo.get(id);
    const deps = [...dependencies.get(id)];
    const best = deps.length ? Math.max(...deps.map(duration)) : 0;
    const value = tasks.get(id).estimateHours + best;
    memo.set(id, value);
    return value;
  }
  return tasks.size ? Math.max(...[...tasks.keys()].map(duration)) : 0;
}

export function progress() {
  const totalHours = [...tasks.values()].reduce((sum, task) => sum + task.estimateHours, 0);
  const completedHours = [...tasks.values()]
    .filter((task) => task.done)
    .reduce((sum, task) => sum + task.estimateHours, 0);
  const percent = totalHours ? Math.round((completedHours / totalHours) * 10000) / 100 : 0;
  return { completedHours, totalHours, percent };
}
