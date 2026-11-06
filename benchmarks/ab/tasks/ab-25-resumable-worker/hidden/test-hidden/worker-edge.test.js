import test from "node:test";
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { runWorker } from "../src/worker.js";

function paths() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "worker-edge-"));
  return { dir, checkpointPath: path.join(dir, "checkpoint.json"), outputPath: path.join(dir, "out.jsonl") };
}

function readLines(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse);
}

function readCheckpoint(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

test("a limit run resumes without duplicating output", async () => {
  const p = paths();
  const jobs = [{ id: "a" }, { id: "b" }, { id: "c" }, { id: "d" }];
  const worker = async (job) => job.id.toUpperCase();

  const first = await runWorker({ ...p, jobs, worker, limit: 2 });
  assert.deepStrictEqual(first, { processed: 2, nextIndex: 2 });
  assert.deepStrictEqual(readLines(p.outputPath).map((line) => line.id), ["a", "b"]);

  const second = await runWorker({ ...p, jobs, worker });
  assert.deepStrictEqual(second, { processed: 2, nextIndex: 4 });
  assert.deepStrictEqual(readLines(p.outputPath).map((line) => line.id), ["a", "b", "c", "d"]);
  assert.strictEqual(readCheckpoint(p.checkpointPath).nextIndex, 4);
});

test("a failed job does not advance the checkpoint and is retried", async () => {
  const p = paths();
  const jobs = [{ id: "a" }, { id: "b" }, { id: "c" }];
  const failing = async (job) => {
    if (job.id === "b") throw new Error("boom");
    return job.id;
  };

  await assert.rejects(runWorker({ ...p, jobs, worker: failing }), /boom/);
  assert.strictEqual(readCheckpoint(p.checkpointPath).nextIndex, 1);
  assert.deepStrictEqual(readLines(p.outputPath).map((line) => line.id), ["a"]);

  const retry = await runWorker({ ...p, jobs, worker: async (job) => job.id });
  assert.deepStrictEqual(retry, { processed: 2, nextIndex: 3 });
  assert.deepStrictEqual(readLines(p.outputPath).map((line) => line.id), ["a", "b", "c"]);
});

test("malformed and unsupported checkpoints fail without touching output", async () => {
  const p = paths();
  fs.writeFileSync(p.checkpointPath, "{not json");
  await assert.rejects(runWorker({ ...p, jobs: [{ id: "a" }], worker: async () => 1 }),
    /invalid checkpoint/);
  assert.strictEqual(fs.existsSync(p.outputPath), false);

  fs.writeFileSync(p.checkpointPath, JSON.stringify({ version: 2, nextIndex: 0 }));
  await assert.rejects(runWorker({ ...p, jobs: [{ id: "a" }], worker: async () => 1 }),
    /unsupported checkpoint version: 2/);
});

test("a lock prevents a second worker and is removed afterwards", async () => {
  const p = paths();
  const lock = `${p.checkpointPath}.lock`;
  fs.writeFileSync(lock, "other");

  await assert.rejects(
    runWorker({ ...p, jobs: [{ id: "a" }], worker: async () => 1 }),
    /worker already running/,
  );

  fs.rmSync(lock);
  await runWorker({ ...p, jobs: [{ id: "a" }], worker: async () => 1 });
  assert.strictEqual(fs.existsSync(lock), false);
});

test("the checkpoint is written atomically with no temp files left", async () => {
  const p = paths();
  await runWorker({ ...p, jobs: [{ id: "a" }, { id: "b" }], worker: async (job) => job.id });
  const leftovers = fs.readdirSync(p.dir).filter((name) => name.includes(".tmp"));
  assert.deepStrictEqual(leftovers, []);
  assert.deepStrictEqual(readCheckpoint(p.checkpointPath), { version: 1, nextIndex: 2 });
});

test("limit 0 processes nothing, leaves the checkpoint alone and releases the lock", async () => {
  const p = paths();
  const result = await runWorker({ ...p, jobs: [{ id: "a" }], worker: async () => 1, limit: 0 });
  assert.deepStrictEqual(result, { processed: 0, nextIndex: 0 });
  assert.strictEqual(fs.existsSync(p.outputPath), false);
  assert.strictEqual(fs.existsSync(`${p.checkpointPath}.lock`), false);
  assert.strictEqual(fs.existsSync(p.checkpointPath), false);
});

test("an existing checkpoint skips completed jobs", async () => {
  const p = paths();
  fs.writeFileSync(p.checkpointPath, JSON.stringify({ version: 1, nextIndex: 2 }));
  const jobs = [{ id: "a" }, { id: "b" }, { id: "c" }];
  const result = await runWorker({ ...p, jobs, worker: async (job) => job.id });
  assert.deepStrictEqual(result, { processed: 1, nextIndex: 3 });
  assert.deepStrictEqual(readLines(p.outputPath).map((line) => line.id), ["c"]);
});
