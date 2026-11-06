import test from "node:test";
import assert from "node:assert";
import { settle } from "../src/settlement.js";

const config = { base: "USD", rates: { USD: 10000, EUR: 12500 } };

test("positive halves round away from zero", () => {
  const result = settle([{ account: "a", currency: "EUR", amountCents: 2 }], config);
  assert.strictEqual(result.totalBaseCents, 3);
});

test("negative halves round away from zero", () => {
  const result = settle([{ account: "a", currency: "EUR", amountCents: -2 }], config);
  assert.strictEqual(result.totalBaseCents, -3);
});

test("accounts net converted entries and sort", () => {
  const result = settle([
    { account: "b", currency: "USD", amountCents: 100 },
    { account: "a", currency: "EUR", amountCents: 2 },
    { account: "a", currency: "USD", amountCents: -10 },
  ], config);
  assert.strictEqual(result.totalBaseCents, 93);
  assert.deepStrictEqual(result.byAccount,
    [{ account: "a", baseCents: -7 }, { account: "b", baseCents: 100 }]);
});

test("unknown currencies fail", () => {
  assert.throws(() => settle([{ account: "a", currency: "GBP", amountCents: 1 }], config),
    { message: "unknown_rate: GBP" });
});

test("invalid amounts and rates fail", () => {
  assert.throws(() => settle([{ account: "a", currency: "USD", amountCents: 1.5 }], config),
    { message: "invalid_amount" });
  assert.throws(() => settle([], { base: "USD", rates: { USD: 0 } }),
    { message: "invalid_base_rate" });
  assert.throws(() => settle([{ account: "a", currency: "USD", amountCents: 1 }],
    { base: "USD", rates: { USD: 10000, EUR: -1 } }),
    { message: "invalid_rate: EUR" });
});

test("empty entries return zero totals", () => {
  assert.deepStrictEqual(settle([], config), { totalBaseCents: 0, byAccount: [] });
});
