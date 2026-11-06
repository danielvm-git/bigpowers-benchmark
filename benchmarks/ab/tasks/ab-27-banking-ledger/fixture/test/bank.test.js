import test from "node:test";
import assert from "node:assert";
import { balance, createAccount, reset, transfer } from "../src/bank.js";

test("creates accounts and transfers money", () => {
  reset();
  createAccount({ id: "A", owner: "Ana", balanceCents: 1000 });
  createAccount({ id: "B", owner: "Bruno", balanceCents: 500 });
  transfer({ idempotencyKey: "visible-1", from: "A", to: "B", amountCents: 300 });
  assert.strictEqual(balance("A"), 700);
  assert.strictEqual(balance("B"), 800);
});
