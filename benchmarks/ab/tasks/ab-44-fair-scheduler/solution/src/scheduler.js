function fail(code) { throw new Error(code); }
function validJob(job) {
  return job && typeof job.id === "string" && Number.isInteger(job.priority)
    && job.priority >= 1 && job.priority <= 5 && Number.isInteger(job.runtime)
    && job.runtime > 0 && Number.isInteger(job.arrival) && job.arrival >= 0;
}
export function runScheduler(jobs, config = {}) {
  const quantum = config.quantum ?? 2; const agingAfter = config.agingAfter ?? 2;
  if (!Number.isInteger(quantum) || quantum <= 0 || !Number.isInteger(agingAfter) || agingAfter <= 0) {
    fail("invalid_config");
  }
  const seen = new Set();
  for (const job of jobs) {
    if (!validJob(job)) fail(`invalid_job: ${job?.id ?? "unknown"}`);
    if (seen.has(job.id)) fail(`duplicate_job: ${job.id}`);
    seen.add(job.id);
  }
  const pending = jobs.map((job) => ({ ...job, remaining: job.runtime, lastRunAt: job.arrival }));
  const order = []; const completions = []; let time = 0;
  while (pending.some((job) => job.remaining > 0)) {
    const ready = pending.filter((job) => job.arrival <= time && job.remaining > 0);
    if (!ready.length) {
      time = Math.min(...pending.filter((job) => job.remaining > 0).map((job) => job.arrival));
      continue;
    }
    ready.sort((a, b) => {
      const ea = a.priority + Math.floor((time - a.lastRunAt) / agingAfter);
      const eb = b.priority + Math.floor((time - b.lastRunAt) / agingAfter);
      return eb - ea || a.arrival - b.arrival || a.id.localeCompare(b.id);
    });
    const job = ready[0];
    const slice = Math.min(quantum, job.remaining);
    time += slice; job.remaining -= slice; job.lastRunAt = time;
    if (job.remaining === 0) { order.push(job.id); completions.push({ id: job.id, at: time }); }
  }
  return { order, completions };
}
