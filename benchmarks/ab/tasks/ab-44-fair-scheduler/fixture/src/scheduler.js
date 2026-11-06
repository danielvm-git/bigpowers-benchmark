export function runScheduler(jobs, config = {}) {
  const quantum = config.quantum ?? 2;
  let time = 0;
  const order = []; const completions = [];
  const pending = jobs.map((job) => ({ ...job, remaining: job.runtime }));
  while (pending.some((job) => job.remaining > 0)) {
    const ready = pending.filter((job) => job.arrival <= time && job.remaining > 0);
    if (!ready.length) { time = Math.min(...pending.map((job) => job.arrival)); continue; }
    ready.sort((a, b) => b.priority - a.priority || a.arrival - b.arrival);
    const job = ready[0];
    const slice = Math.min(quantum, job.remaining);
    time += slice; job.remaining -= slice;
    if (job.remaining === 0) { order.push(job.id); completions.push({ id: job.id, at: time }); }
  }
  return { order, completions };
}
