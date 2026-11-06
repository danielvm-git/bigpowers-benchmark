import test from "node:test";
import assert from "node:assert";
import { balance, createAccount, ledger, reset, transfer } from "../src/bank.js";

function setup() {
  reset();
  createAccount({ id: "A", owner: "Ana", balanceCents: 1000 });
  createAccount({ id: "B", owner: "Bruno", balanceCents: 500 });
}

test("a transfer writes two entries and the ledger sums to zero", () => {
  setup();
  const tx = transfer({ idempotencyKey: "k1", from: "A", to: "B", amountCents: 300 });
  assert.strictEqual(balance("A"), 700);
  assert.strictEqual(balance("B"), 800);
  const a = ledger("A");
  const b = ledger("B");
  assert.strictEqual(a.length, 1);
  assert.strictEqual(b.length, 1);
  assert.strictEqual(a[0].amountCents, -300);
  assert.strictEqual(b[0].amountCents, 300);
  assert.strictEqual(a[0].transferId, b[0].transferId);
  assert.strictEqual(a[0].transferId, tx.id);
});

test("insufficient funds leaves balances and ledger untouched", () => {
  setup();
  assert.throws(() => transfer({ idempotencyKey: "k2", from: "A", to: "B", amountCents: 1001 }),
    { message: "insufficient_funds" });
  assert.strictEqual(balance("A"), 1000);
  assert.strictEqual(balance("B"), 500);
  assert.deepStrictEqual(ledger("A"), []);
});

test("unknown accounts and same-account transfers fail", () => {
  setup();
  assert.throws(() => transfer({ idempotencyKey: "k3", from: "X", to: "B", amountCents: 1 }),
    { message: "account_not_found: X" });
  assert.throws(() => transfer({ idempotencyKey: "k4", from: "A", to: "A", amountCents: 1 }),
    { message: "same_account" });
});

test("amount and currency are validated", () => {
  setup();
  for (const amountCents of [0, -1, 1.5, "10"]) {
    assert.throws(() => transfer({ idempotencyKey: `bad-${amountCents}`, from: "A", to: "B", amountCents }),
      { message: "invalid_amount" });
  }
  createAccount({ id: "C", owner: "Carla", currency: "USD", balanceCents: 100 });
  assert.throws(() => transfer({ idempotencyKey: "k5", from: "A", to: "C", amountCents: 10 }),
    { message: "currency_mismatch" });
});

test("an idempotency key applies the money exactly once", () => {
  setup();
  const first = transfer({ idempotencyKey: "same", from: "A", to: "B", amountCents: 100 });
  const second = transfer({ idempotencyKey: "same", from: "A", to: "B", amountCents: 100 });
  assert.deepStrictEqual(second, first);
  assert.strictEqual(balance("A"), 900);
  assert.strictEqual(balance("B"), 600);
  assert.strictEqual(ledger("A").length, 1);
});

test("different idempotency keys are different transfers", () => {
  setup();
  const first = transfer({ idempotencyKey: "k6", from: "A", to: "B", amountCents: 100 });
  const second = transfer({ idempotencyKey: "k7", from: "A", to: "B", amountCents: 100 });
  assert.notStrictEqual(first.id, second.id);
  assert.strictEqual(balance("A"), 800);
  assert.strictEqual(ledger("A").length, 2);
});

test("duplicate accounts and negative opening balances are rejected", () => {
  setup();
  assert.throws(() => createAccount({ id: "A", owner: "Again" }),
    { message: "duplicate_account: A" });
  assert.throws(() => createAccount({ id: "D", owner: "D", balanceCents: -1 }),
    { message: "invalid_balance" });
});

test("concurrent transfers never overdraw and keep the total", () => {
  reset();
  createAccount({ id: "A", owner: "Ana", balanceCents: 1000 });
  createAccount({ id: "B", owner: "Bruno", balanceCents: 0 });
  const results = [];
  for (let i = 0; i < 10; i += 1) {
    results.push(Promise.resolve().then(() =>
      transfer({ idempotencyKey: `c${i}`, from: "A", to: "B", amountCents: 100 })));
  }
  return Promise.all(results).then(() => {
    assert.strictEqual(balance("A"), 0);
    assert.strictEqual(balance("B"), 1000);
    assert.strictEqual(ledger("A").length, 10);
    assert.strictEqual(ledger("B").length, 10);
    const all = [...ledger("A"), ...ledger("B")];
    assert.strictEqual(all.reduce((sum, entry) => sum + entry.amountCents, 0), 0);
  });
});

test("ledger and balance reject unknown accounts", () => {
  setup();
  assert.throws(() => ledger("X"), { message: "account_not_found: X" });
  assert.throws(() => balance("X"), { message: "account_not_found: X" });
});
