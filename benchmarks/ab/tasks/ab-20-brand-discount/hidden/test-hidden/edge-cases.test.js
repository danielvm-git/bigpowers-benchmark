import test from "node:test";
import assert from "node:assert";
import { parseOrder, priceOrder } from "../src/orders.js";

const CATALOG = {
  "ACME-ANVIL": { name: "Acme Anvil", priceCents: 4000, category: "tools", brand: "acme", weightGrams: 5000 },
  "ACME-HAMMER": { name: "Acme Hammer", priceCents: 1500, category: "tools", brand: "acme", weightGrams: 800 },
  "ZEN-RADIO": { name: "Zenith Radio", priceCents: 2000, category: "electronics", brand: "zenith", weightGrams: 600 },
  "GEN-BOOK": { name: "Notebook", priceCents: 1000, category: "stationery", weightGrams: 200 },
  "BOOK-1": { name: "Novel", priceCents: 1000, category: "books", weightGrams: 100 },
  "CASE-ACME": { name: "Acme Case", priceCents: 3333, category: "tools", brand: "Acme", weightGrams: 100 },
  "CASE-ROUND": { name: "Acme Rounding Case", priceCents: 3333, category: "tools", brand: "acme", weightGrams: 100 },
};

function order(lines, code = null) {
  return `order: B-3001
customer: Carlos Silva <carlos@example.com>
region: PT
date: 2026-06-15
${lines}
${code ? `code: ${code}\n` : ""}`;
}

test("the minimum brand subtotal is inclusive", () => {
  const priced = priceOrder(parseOrder(order("item: ACME-HAMMER x2", "ACME20")), CATALOG);
  assert.strictEqual(priced.discountCents, 600);
  assert.strictEqual(priced.lines[0].discountCents, 600);
});

test("brand matching is case-sensitive", () => {
  assert.throws(
    () => priceOrder(parseOrder(order("item: CASE-ACME x1", "ACME20")), CATALOG),
    { message: "discount code ACME20 needs items from brand: acme" }
  );
});

test("a brand percentage rounds to the nearest cent", () => {
  const priced = priceOrder(parseOrder(order("item: CASE-ROUND x1", "ACME20")), CATALOG);
  // 3333 * 20% = 666.6 -> 667
  assert.strictEqual(priced.discountCents, 667);
});

test("no code means no discount and no label", () => {
  const priced = priceOrder(parseOrder(order("item: ACME-ANVIL x1")), CATALOG);
  assert.strictEqual(priced.discountCents, 0);
  assert.strictEqual(priced.discountLabel, null);
});

test("regression: BULK still uses the quantity tiers", () => {
  const priced = priceOrder(parseOrder(order("item: GEN-BOOK x5", "BULK")), CATALOG);
  assert.strictEqual(priced.discountCents, 350);
});

test("regression: BOGO-BOOKS still gives the cheapest book free", () => {
  const priced = priceOrder(parseOrder(order("item: BOOK-1 x2", "BOGO-BOOKS")), CATALOG);
  assert.strictEqual(priced.discountCents, 1000);
});
