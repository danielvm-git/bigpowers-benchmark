import test from "node:test";
import assert from "node:assert";
import { reset, addWarehouse, setStock, placeOrder } from "../src/fulfillment.js";

test("allocates from a warehouse", () => {
  reset(); addWarehouse({ id: "w1", priority: 1 }); setStock({ warehouseId: "w1", sku: "a", qty: 5 });
  const current = placeOrder({ id: "o1", items: [{ sku: "a", qty: 2 }] });
  assert.strictEqual(current.status, "allocated");
});
