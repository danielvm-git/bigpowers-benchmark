import test from "node:test";
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { runWorker } from "../src/worker.js";

function paths() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "worker-"));
  return { dir, checkpointPath: path.join(dir, "checkpoint.json"), outputPath: path.join(dir, "out.jsonl") };
}

test("processes every job and writes a checkpoint", async () => {
  const p = paths();
  const jobs = [{ id: "a" }, { id: "b" }, { id: "c" }];
  const result = await runWorker({ ...p, jobs, worker: async (job) => job.id.toUpperCase() });
  assert.strictEqual(result.processed, 3);
  assert.strictEqual(result.nextIndex, 3);
  const lines = fs.readFileSync(p.outputPath, "utf8").trim().split("\n");
  assert.strictEqual(lines.length, 3);
  assert.deepStrictEqual(JSON.parse(lines[1]), { id: "b", result: "B" });
});
