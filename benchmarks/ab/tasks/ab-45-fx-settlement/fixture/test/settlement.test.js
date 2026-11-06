import test from "node:test";
import assert from "node:assert";
import { settle } from "../src/settlement.js";

test("converts a single entry at par", () => {
  const result = settle([{ account: "a", currency: "USD", amountCents: 100 }],
    { base: "USD", rates: { USD: 10000 } });
  assert.strictEqual(result.totalBaseCents, 100);
  assert.deepStrictEqual(result.byAccount, [{ account: "a", baseCents: 100 }]);
});
