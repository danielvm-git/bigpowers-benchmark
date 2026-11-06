import test from "node:test";
import assert from "node:assert";
import { reset, createOrder, pay, order } from "../src/orders.js";

test("pay moves a created order to paid", () => {
  reset(); createOrder({ id: "o1", items: ["a"], totalCents: 100 });
  pay({ id: "o1", paymentId: "p1" });
  assert.strictEqual(order("o1").status, "paid");
});
