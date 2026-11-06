import test from "node:test";
import assert from "node:assert";
import { getProductById, searchProducts } from "../src/catalog.js";

test("staff_only products are hidden from every non-internal role", () => {
  for (const role of ["anonymous", "customer", "vip"]) {
    assert.throws(() => getProductById("PROD-4", role),
                  { message: "product not found: PROD-4" });
  }
  assert.strictEqual(getProductById("PROD-4", "internal").id, "PROD-4");
});

test("customer cannot see a vip product, vip can see a customer product", () => {
  assert.throws(() => getProductById("PROD-3", "customer"),
                { message: "product not found: PROD-3" });
  assert.strictEqual(getProductById("PROD-2", "vip").id, "PROD-2");
});

test("unknown ids are absent for every role", () => {
  for (const role of ["anonymous", "customer", "vip", "internal"]) {
    assert.throws(() => getProductById("PROD-999", role),
                  { message: "product not found: PROD-999" });
  }
});

test("search counts only visible products for each role", () => {
  const cases = {
    anonymous: 1,
    customer: 2,
    vip: 3,
    internal: 5,
  };
  for (const [role, total] of Object.entries(cases)) {
    const result = searchProducts("", null, role);
    assert.strictEqual(result.total, total, role);
    assert.strictEqual(Object.values(result.facets).reduce((a, b) => a + b, 0), total, role);
  }
});

test("query and category filters cannot reveal hidden products", () => {
  assert.strictEqual(searchProducts("coffee", null, "anonymous").total, 0);
  assert.strictEqual(searchProducts("coffee", null, "customer").total, 1);
  assert.strictEqual(searchProducts("", "hardware", "anonymous").total, 0);
  assert.strictEqual(searchProducts("", "hardware", "internal").total, 1);
  assert.strictEqual(searchProducts("gold", null, "anonymous").total, 0);
  assert.strictEqual(searchProducts("gold", null, "vip").total, 1);
});
