import test from "node:test";
import assert from "node:assert";
import { reset, addWarehouse, setStock, placeOrder, fulfill, cancel, order, available }
  from "../src/fulfillment.js";

function setup() {
  reset();
  addWarehouse({ id: "w2", priority: 2 }); addWarehouse({ id: "w1", priority: 1 });
  setStock({ warehouseId: "w1", sku: "a", qty: 2 });
  setStock({ warehouseId: "w2", sku: "a", qty: 5 });
}

test("allocates by priority then id", () => {
  setup();
  const current = placeOrder({ id: "o1", items: [{ sku: "a", qty: 4 }] });
  assert.deepStrictEqual(current.allocations,
    [{ sku: "a", warehouseId: "w1", qty: 2 }, { sku: "a", warehouseId: "w2", qty: 2 }]);
});

test("reservations reduce availability", () => {
  setup();
  placeOrder({ id: "o1", items: [{ sku: "a", qty: 4 }] });
  assert.strictEqual(available("a"), 3);
  placeOrder({ id: "o2", items: [{ sku: "a", qty: 4 }] });
  assert.strictEqual(available("a"), 0);
});

test("insufficient stock backorders the shortfall", () => {
  setup();
  const current = placeOrder({ id: "o1", items: [{ sku: "a", qty: 9 }] });
  assert.strictEqual(current.status, "backordered");
  assert.strictEqual(current.backordered, 2);
  assert.strictEqual(available("a"), 0);
});

test("placeOrder is atomic on invalid items", () => {
  setup();
  assert.throws(() => placeOrder({ id: "bad", items: [{ sku: "a", qty: 0 }] }),
    { message: "invalid_order" });
  assert.strictEqual(available("a"), 7);
  assert.strictEqual(order("bad"), undefined);
});

test("fulfill consumes physical stock and clears reservations", () => {
  setup();
  placeOrder({ id: "o1", items: [{ sku: "a", qty: 4 }] });
  fulfill({ id: "o1" });
  assert.strictEqual(available("a"), 3);
  assert.strictEqual(order("o1").status, "fulfilled");
  assert.deepStrictEqual(order("o1").allocations, []);
});

test("backordered orders cannot be fulfilled", () => {
  setup();
  placeOrder({ id: "o1", items: [{ sku: "a", qty: 9 }] });
  assert.throws(() => fulfill({ id: "o1" }), { message: "invalid_transition" });
});

test("cancel releases reservations", () => {
  setup();
  placeOrder({ id: "o1", items: [{ sku: "a", qty: 4 }] });
  cancel({ id: "o1" });
  assert.strictEqual(available("a"), 7);
  assert.strictEqual(order("o1").status, "cancelled");
});

test("fulfilled orders cannot be cancelled", () => {
  setup();
  placeOrder({ id: "o1", items: [{ sku: "a", qty: 1 }] });
  fulfill({ id: "o1" });
  assert.throws(() => cancel({ id: "o1" }), { message: "invalid_transition" });
});

test("stock cannot drop below reservations", () => {
  setup();
  placeOrder({ id: "o1", items: [{ sku: "a", qty: 4 }] });
  assert.throws(() => setStock({ warehouseId: "w1", sku: "a", qty: 1 }),
    { message: "stock_below_reserved" });
  assert.strictEqual(available("a"), 3);
});

test("duplicates and unknown ids fail", () => {
  setup();
  assert.throws(() => addWarehouse({ id: "w1", priority: 3 }),
    { message: "duplicate_warehouse: w1" });
  placeOrder({ id: "o1", items: [{ sku: "a", qty: 1 }] });
  assert.throws(() => placeOrder({ id: "o1", items: [{ sku: "a", qty: 1 }] }),
    { message: "duplicate_order: o1" });
  assert.throws(() => cancel({ id: "nope" }), { message: "order_not_found: nope" });
});
