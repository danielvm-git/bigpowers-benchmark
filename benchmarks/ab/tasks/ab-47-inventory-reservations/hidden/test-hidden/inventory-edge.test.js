import test from "node:test";
import assert from "node:assert";
import { reset, addItem, reserve, confirm, cancel, sweep, available, reservation }
  from "../src/inventory.js";

test("reservations hold stock", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  assert.strictEqual(available("a", 0), 3);
  assert.throws(() => reserve({ sku: "a", qty: 4, now: 0, ttl: 10 }),
    { message: "insufficient_stock: a" });
});

test("expiry is exact and frees the hold", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  assert.strictEqual(available("a", 9), 3);
  assert.strictEqual(available("a", 10), 5);
});

test("confirm reduces stock and releases the hold", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  const { id } = reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  confirm({ id, now: 1 });
  assert.strictEqual(available("a", 1), 3);
  assert.strictEqual(reservation(id).status, "confirmed");
});

test("expired reservations cannot be confirmed or cancelled", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  const { id } = reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  assert.throws(() => confirm({ id, now: 10 }), { message: "reservation_expired" });
  assert.throws(() => cancel({ id, now: 10 }), { message: "reservation_expired" });
  assert.strictEqual(available("a", 10), 5);
});

test("cancel releases the hold", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  const { id } = reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  cancel({ id, now: 1 });
  assert.strictEqual(available("a", 1), 5);
  assert.throws(() => cancel({ id, now: 1 }), { message: "reservation_not_pending" });
});

test("sweep expires once and is idempotent", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  assert.strictEqual(sweep(10), 1);
  assert.strictEqual(sweep(11), 0);
  assert.strictEqual(available("a", 10), 5);
});

test("double confirm fails without stock changes", () => {
  reset(); addItem({ sku: "a", stock: 5 });
  const { id } = reserve({ sku: "a", qty: 2, now: 0, ttl: 10 });
  confirm({ id, now: 1 });
  assert.throws(() => confirm({ id, now: 2 }), { message: "reservation_not_pending" });
  assert.strictEqual(available("a", 2), 3);
});

test("duplicate items and unknown ids fail", () => {
  reset(); addItem({ sku: "a", stock: 1 });
  assert.throws(() => addItem({ sku: "a", stock: 2 }), { message: "duplicate_item: a" });
  assert.throws(() => reserve({ sku: "missing", qty: 1, now: 0, ttl: 1 }),
    { message: "item_not_found: missing" });
  assert.throws(() => confirm({ id: "r99", now: 0 }), { message: "reservation_not_found: r99" });
});
