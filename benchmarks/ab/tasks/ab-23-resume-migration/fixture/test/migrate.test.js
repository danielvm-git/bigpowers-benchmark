import test from "node:test";
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { runMigration } from "../src/migrate.js";

test("normalizes orders and builds the customer index", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "migrate-"));
  fs.copyFileSync(new URL("../data/orders.json", import.meta.url), path.join(dir, "orders.json"));
  fs.copyFileSync(new URL("../data/customers.json", import.meta.url), path.join(dir, "customers.json"));

  runMigration(dir);

  const orders = JSON.parse(fs.readFileSync(path.join(dir, "orders.normalized.json"), "utf8"));
  assert.strictEqual(orders.length, 3);
  assert.strictEqual(orders[0].totalCents, 1000);
  assert.strictEqual(orders[0].itemCount, 2);

  const index = JSON.parse(fs.readFileSync(path.join(dir, "customers.index.json"), "utf8"));
  assert.strictEqual(index["C-1"].name, "Ana");
});
