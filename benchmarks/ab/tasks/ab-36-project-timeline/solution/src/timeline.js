const projects = new Map();
const tasks = new Map();
export function reset() { projects.clear(); tasks.clear(); }
function fail(code) { throw new Error(code); }
function requireProject(id) { if (!projects.has(id)) fail(`project_not_found: ${id}`); }
function requireTask(id) { const t = tasks.get(id); if (!t) fail(`task_not_found: ${id}`); return t; }

export function createProject({ id, name }) {
  if (typeof id !== "string" || !id) fail("invalid_project_id");
  if (projects.has(id)) fail(`duplicate_project: ${id}`);
  const project = { id, name }; projects.set(id, project); return { ...project };
}
export function addTask({ id, projectId, estimateHours }) {
  requireProject(projectId);
  if (typeof id !== "string" || !id) fail("invalid_task_id");
  if (tasks.has(id)) fail(`duplicate_task: ${id}`);
  if (!Number.isInteger(estimateHours) || estimateHours <= 0) fail("invalid_estimate");
  const task = { id, projectId, estimateHours, delay: 0, dependsOn: new Set() };
  tasks.set(id, task); return { ...task, dependsOn: [] };
}
function reaches(from, target) {
  const seen = new Set(); const stack = [from];
  while (stack.length) {
    const current = stack.pop();
    if (current === target) return true;
    if (seen.has(current)) continue;
    seen.add(current);
    for (const next of tasks.get(current)?.dependsOn ?? []) stack.push(next);
  }
  return false;
}
export function addDependency({ taskId, dependsOn }) {
  const task = requireTask(taskId); const dependency = requireTask(dependsOn);
  if (task.projectId !== dependency.projectId) fail("cross_project_dependency");
  if (taskId === dependsOn) fail("cycle_detected");
  if (task.dependsOn.has(dependsOn)) return;
  if (reaches(dependsOn, taskId)) fail("cycle_detected");
  task.dependsOn.add(dependsOn);
}
export function delayTask({ taskId, hours }) {
  const task = requireTask(taskId);
  if (!Number.isInteger(hours) || hours < 0) fail("invalid_delay");
  task.delay += hours;
  return { taskId, delay: task.delay };
}
function order(projectId) {
  const rows = [...tasks.values()].filter((t) => t.projectId === projectId);
  const indegree = new Map(rows.map((t) => [t.id, t.dependsOn.size]));
  const dependants = new Map(rows.map((t) => [t.id, []]));
  for (const task of rows) for (const dep of task.dependsOn) dependants.get(dep).push(task.id);
  const ready = rows.filter((t) => indegree.get(t.id) === 0).map((t) => t.id).sort();
  const out = [];
  while (ready.length) {
    const id = ready.shift(); out.push(id);
    for (const next of dependants.get(id)) {
      indegree.set(next, indegree.get(next) - 1);
      if (indegree.get(next) === 0) { ready.push(next); ready.sort(); }
    }
  }
  if (out.length !== rows.length) fail("cycle_detected");
  return out;
}
export function schedule({ projectId }) {
  requireProject(projectId);
  const rows = [];
  const end = new Map();
  for (const id of order(projectId)) {
    const task = tasks.get(id);
    const start = task.dependsOn.size ? Math.max(...[...task.dependsOn].map((dep) => end.get(dep))) : 0;
    const finish = start + task.estimateHours + task.delay;
    end.set(id, finish);
    rows.push({ id, start, end: finish });
  }
  return { tasks: rows, projectEnd: rows.length ? Math.max(...rows.map((r) => r.end)) : 0 };
}
export function criticalPath({ projectId }) {
  requireProject(projectId);
  const rows = [...tasks.values()].filter((t) => t.projectId === projectId);
  if (rows.length === 0) return { path: [], durationHours: 0 };
  const memo = new Map();
  function duration(id) {
    if (memo.has(id)) return memo.get(id);
    const task = tasks.get(id);
    const depDurations = [...task.dependsOn].map(duration);
    const value = task.estimateHours + task.delay + (depDurations.length ? Math.max(...depDurations) : 0);
    memo.set(id, value); return value;
  }
  for (const task of rows) duration(task.id);
  const root = [...rows].sort((a, b) => duration(b.id) - duration(a.id) || a.id.localeCompare(b.id))[0];
  const path = [];
  let current = root.id;
  while (current) {
    path.push(current);
    const deps = [...tasks.get(current).dependsOn];
    if (!deps.length) break;
    current = deps.sort((a, b) => duration(b) - duration(a) || a.localeCompare(b))[0];
  }
  return { path: path.reverse(), durationHours: duration(root.id) };
}
