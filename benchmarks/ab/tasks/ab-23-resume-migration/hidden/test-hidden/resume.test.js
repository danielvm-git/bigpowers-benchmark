import test from "node:test";
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { runMigration } from "../src/migrate.js";

const DATA = new URL("../data/", import.meta.url);

function fixture() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "resume-"));
  for (const name of ["orders.json", "orders.normalized.json", "customers.json",
                      "customers.index.json", "migration-state.json"]) {
    fs.copyFileSync(new URL(name, DATA), path.join(dir, name));
  }
  return dir;
}

function read(dir, name) {
  return fs.readFileSync(path.join(dir, name), "utf8");
}

function state(dir) {
  return JSON.parse(read(dir, "migration-state.json")).completedSteps;
}

test("resumes at step 3 and does not rewrite completed outputs", () => {
  const dir = fixture();
  const normalizedBefore = read(dir, "orders.normalized.json");
  const indexBefore = read(dir, "customers.index.json");

  runMigration(dir);
  assert.deepStrictEqual(state(dir), [1, 2, 3]);

  const summary = JSON.parse(read(dir, "summary.json"));
  assert.deepStrictEqual(summary, { orderCount: 3, customerCount: 2, revenueCents: 2700 });
  assert.strictEqual(read(dir, "orders.normalized.json"), normalizedBefore);
  assert.strictEqual(read(dir, "customers.index.json"), indexBefore);
});

test("a second run is a no-op", () => {
  const dir = fixture();
  runMigration(dir);
  const summaryBefore = read(dir, "summary.json");
  const stateBefore = read(dir, "migration-state.json");
  runMigration(dir);
  assert.strictEqual(read(dir, "summary.json"), summaryBefore);
  assert.strictEqual(read(dir, "migration-state.json"), stateBefore);
});

test("a missing output reopens its step", () => {
  const dir = fixture();
  fs.unlinkSync(path.join(dir, "orders.normalized.json"));
  runMigration(dir);
  assert.deepStrictEqual(state(dir), [1, 2, 3]);
  assert.ok(fs.existsSync(path.join(dir, "orders.normalized.json")));
  assert.ok(fs.existsSync(path.join(dir, "summary.json")));
});

test("state [1] reruns steps 2 and 3 but not step 1", () => {
  const dir = fixture();
  fs.writeFileSync(path.join(dir, "migration-state.json"),
    JSON.stringify({ version: 1, completedSteps: [1] }));
  const normalizedBefore = read(dir, "orders.normalized.json");

  runMigration(dir);
  assert.deepStrictEqual(state(dir), [1, 2, 3]);
  assert.strictEqual(read(dir, "orders.normalized.json"), normalizedBefore);
  assert.ok(fs.existsSync(path.join(dir, "customers.index.json")));
});

test("a clean directory runs all three steps", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "resume-clean-"));
  for (const name of ["orders.json", "customers.json"]) {
    fs.copyFileSync(new URL(name, DATA), path.join(dir, name));
  }
  runMigration(dir);
  assert.deepStrictEqual(state(dir), [1, 2, 3]);
  assert.deepStrictEqual(JSON.parse(read(dir, "summary.json")),
    { orderCount: 3, customerCount: 2, revenueCents: 2700 });
});

test("a missing input fails without advancing the state", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "resume-missing-"));
  fs.copyFileSync(new URL("customers.json", DATA), path.join(dir, "customers.json"));
  assert.throws(() => runMigration(dir));
  assert.strictEqual(fs.existsSync(path.join(dir, "migration-state.json")), false);
});
