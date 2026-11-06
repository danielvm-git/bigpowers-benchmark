import test from "node:test";
import assert from "node:assert";
import { reset, createOrder, pay, ship, cancel, order } from "../src/orders.js";

function make(id = "o1") {
  reset(); createOrder({ id, items: ["a"], totalCents: 100 }); return id;
}

test("pay is idempotent with the same payment id", () => {
  const id = make();
  pay({ id, paymentId: "p1" });
  pay({ id, paymentId: "p1" });
  assert.deepStrictEqual(order(id).history, [{ action: "paid" }]);
});

test("a different payment id conflicts", () => {
  const id = make();
  pay({ id, paymentId: "p1" });
  assert.throws(() => pay({ id, paymentId: "p2" }), { message: "payment_conflict" });
  assert.strictEqual(order(id).paymentId, "p1");
});

test("ship requires payment and is idempotent", () => {
  const id = make();
  assert.throws(() => ship({ id, tracking: "t1" }), { message: "invalid_transition" });
  pay({ id, paymentId: "p1" });
  ship({ id, tracking: "t1" });
  ship({ id, tracking: "t1" });
  assert.deepStrictEqual(order(id).history, [{ action: "paid" }, { action: "shipped" }]);
});

test("cancelling a paid order records a refund", () => {
  const id = make();
  pay({ id, paymentId: "p1" });
  cancel({ id });
  assert.deepStrictEqual(order(id).history,
    [{ action: "paid" }, { action: "refunded" }, { action: "cancelled" }]);
});

test("shipped orders cannot be cancelled", () => {
  const id = make();
  pay({ id, paymentId: "p1" }); ship({ id, tracking: "t1" });
  assert.throws(() => cancel({ id }), { message: "invalid_transition" });
  assert.strictEqual(order(id).status, "shipped");
});

test("failed transitions do not mutate history", () => {
  const id = make();
  assert.throws(() => cancel({ id: "missing" }), { message: "order_not_found: missing" });
  assert.deepStrictEqual(order(id).history, []);
});

test("duplicate and invalid orders fail", () => {
  const id = make();
  assert.throws(() => createOrder({ id, items: ["a"], totalCents: 100 }),
    { message: "duplicate_order: o1" });
  assert.throws(() => createOrder({ id: "o2", items: [], totalCents: 100 }),
    { message: "invalid_order" });
});
