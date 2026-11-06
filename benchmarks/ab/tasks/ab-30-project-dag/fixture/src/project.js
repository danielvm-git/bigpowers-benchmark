const tasks = new Map();
const dependencies = new Map();

export function reset() {
  tasks.clear();
  dependencies.clear();
}

export function addTask({ id, title, estimateHours = 1 }) {
  const task = { id, title, estimateHours, done: false };
  tasks.set(id, task);
  dependencies.set(id, new Set());
  return { ...task };
}

export function addDependency({ taskId, dependsOn }) {
  dependencies.get(taskId).add(dependsOn);
}

export function completeTask(id) {
  const task = tasks.get(id);
  task.done = true;
  return { ...task };
}

export function topologicalOrder() {
  return [...tasks.keys()];
}

export function projectDurationHours() {
  return [...tasks.values()].reduce((sum, task) => sum + task.estimateHours, 0);
}

export function progress() {
  const total = tasks.size;
  const completed = [...tasks.values()].filter((task) => task.done).length;
  return { completedHours: completed, totalHours: total, percent: total ? Math.round((completed / total) * 10000) / 100 : 0 };
}
