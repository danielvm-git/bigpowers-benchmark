import fs from "node:fs";

export async function runWorker({ jobs, checkpointPath, outputPath, worker, limit = Infinity }) {
  const checkpoint = fs.existsSync(checkpointPath)
    ? JSON.parse(fs.readFileSync(checkpointPath, "utf8"))
    : { version: 1, nextIndex: 0 };

  let index = checkpoint.nextIndex;
  let processed = 0;
  for (; index < jobs.length && processed < limit; index += 1) {
    const result = await worker(jobs[index]);
    fs.appendFileSync(outputPath, `${JSON.stringify({ id: jobs[index].id, result })}\n`);
    processed += 1;
  }
  fs.writeFileSync(checkpointPath, JSON.stringify({ version: 1, nextIndex: index }, null, 2));
  return { processed, nextIndex: index };
}
