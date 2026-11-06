import test from "node:test";
import assert from "node:assert";
import { reset, addItem, reserve, confirm, available } from "../src/inventory.js";

test("confirm reduces stock", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  const { id } = reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  confirm({ id, now: 1 });
  assert.strictEqual(available("a", 1), 3);
});
