import fs from "node:fs";
import path from "node:path";

function readCheckpoint(checkpointPath) {
  if (!fs.existsSync(checkpointPath)) return { version: 1, nextIndex: 0 };
  let checkpoint;
  try {
    checkpoint = JSON.parse(fs.readFileSync(checkpointPath, "utf8"));
  } catch {
    throw new Error(`invalid checkpoint: ${checkpointPath}`);
  }
  if (!checkpoint || checkpoint.version !== 1) {
    throw new Error(`unsupported checkpoint version: ${checkpoint?.version}`);
  }
  if (!Number.isInteger(checkpoint.nextIndex) || checkpoint.nextIndex < 0) {
    throw new Error(`invalid checkpoint: ${checkpointPath}`);
  }
  return checkpoint;
}

function writeCheckpointAtomic(checkpointPath, checkpoint) {
  const directory = path.dirname(checkpointPath);
  const temp = path.join(directory, `.${path.basename(checkpointPath)}.${process.pid}.tmp`);
  const fd = fs.openSync(temp, "w");
  try {
    fs.writeFileSync(fd, JSON.stringify(checkpoint, null, 2));
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
  try {
    fs.renameSync(temp, checkpointPath);
  } catch (error) {
    fs.rmSync(temp, { force: true });
    throw error;
  }
}

function acquireLock(lockPath) {
  let fd;
  try {
    fd = fs.openSync(lockPath, "wx");
    fs.writeFileSync(fd, String(process.pid));
  } catch (error) {
    if (error.code === "EEXIST") throw new Error(`worker already running: ${lockPath}`);
    throw error;
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
}

export async function runWorker({ jobs, checkpointPath, outputPath, worker, limit = Infinity }) {
  const checkpoint = readCheckpoint(checkpointPath);
  const lockPath = `${checkpointPath}.lock`;
  acquireLock(lockPath);

  try {
    let index = checkpoint.nextIndex;
    let processed = 0;
    for (; index < jobs.length && processed < limit; index += 1) {
      const result = await worker(jobs[index]);
      fs.appendFileSync(outputPath, `${JSON.stringify({ id: jobs[index].id, result })}\n`);
      writeCheckpointAtomic(checkpointPath, { version: 1, nextIndex: index + 1 });
      processed += 1;
    }
    return { processed, nextIndex: index };
  } finally {
    fs.rmSync(lockPath, { force: true });
  }
}
