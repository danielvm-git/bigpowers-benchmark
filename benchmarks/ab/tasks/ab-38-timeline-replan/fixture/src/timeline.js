const projects = new Map();
const tasks = new Map();
const baselines = new Map();
export function reset() { projects.clear(); tasks.clear(); baselines.clear(); }
export function createProject({ id, name }) { const p = { id, name }; projects.set(id, p); return { ...p }; }
export function addTask({ id, projectId, estimateHours }) { const t = { id, projectId, estimateHours, delay: 0, dependsOn: new Set() }; tasks.set(id, t); return { ...t, dependsOn: [] }; }
export function addDependency({ taskId, dependsOn }) { tasks.get(taskId).dependsOn.add(dependsOn); }
function scheduleFor(projectId) {
  let clock = 0;
  const rows = [...tasks.values()].filter((t) => t.projectId === projectId).sort((a, b) => a.id.localeCompare(b.id));
  for (const task of rows) { task.start = clock; clock += task.estimateHours; task.end = clock; }
  return { tasks: rows.map((t) => ({ id: t.id, start: t.start, end: t.end })), projectEnd: clock };
}
export function baseline({ projectId }) { const result = scheduleFor(projectId); baselines.set(projectId, result); return result; }
export function replan({ projectId, delays = {} }) {
  for (const [id, hours] of Object.entries(delays)) tasks.get(id).delay = hours;
  return scheduleFor(projectId);
}
export function criticalPath({ projectId }) { const rows = [...tasks.values()].filter((t) => t.projectId === projectId); return { path: rows.map((t) => t.id), durationHours: rows.reduce((s, t) => s + t.estimateHours, 0) }; }
