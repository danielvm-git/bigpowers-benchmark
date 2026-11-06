const projects = new Map();
const tasks = new Map();
export function reset() { projects.clear(); tasks.clear(); }
export function createProject({ id, name }) { const p = { id, name }; projects.set(id, p); return { ...p }; }
export function addTask({ id, projectId, estimateHours }) { const t = { id, projectId, estimateHours, dependsOn: [] }; tasks.set(id, t); return { ...t }; }
export function addDependency({ taskId, dependsOn }) { tasks.get(taskId).dependsOn.push(dependsOn); }
export function delayTask({ taskId, hours }) { tasks.get(taskId).delay = hours; }
export function schedule({ projectId }) {
  let clock = 0;
  const rows = [...tasks.values()].filter((t) => t.projectId === projectId).sort((a, b) => a.id.localeCompare(b.id));
  for (const task of rows) { task.start = clock; clock += task.estimateHours; task.end = clock; }
  return { tasks: rows.map((t) => ({ id: t.id, start: t.start, end: t.end })), projectEnd: clock };
}
export function criticalPath({ projectId }) {
  const rows = [...tasks.values()].filter((t) => t.projectId === projectId).sort((a, b) => a.id.localeCompare(b.id));
  return { path: rows.map((t) => t.id), durationHours: rows.reduce((sum, t) => sum + t.estimateHours, 0) };
}
