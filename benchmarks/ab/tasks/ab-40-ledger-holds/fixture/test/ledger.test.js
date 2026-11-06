import test from "node:test";
import assert from "node:assert";
import { authorizeHold, available, balance, captureHold, createAccount, reset } from "../src/ledger.js";
test("holds reduce available and capture debits", () => {
  reset();
  createAccount({ id: "A", balanceCents: 1000 });
  const hold = authorizeHold({ idempotencyKey: "k1", accountId: "A", amountCents: 200 });
  assert.strictEqual(available("A"), 800);
  captureHold({ holdId: hold.id });
  assert.strictEqual(balance("A"), 800);
  assert.strictEqual(available("A"), 800);
});
