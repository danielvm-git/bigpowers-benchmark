import test from "node:test";
import assert from "node:assert";
import {
  authorizeHold, available, balance, captureHold, createAccount, ledger, refund, releaseHold, reset,
} from "../src/ledger.js";

function setup() { reset(); createAccount({ id: "A", balanceCents: 1000 }); }

test("a hold reduces available but not the balance", () => {
  setup();
  const hold = authorizeHold({ idempotencyKey: "h1", accountId: "A", amountCents: 200 });
  assert.strictEqual(balance("A"), 1000);
  assert.strictEqual(available("A"), 800);
  assert.strictEqual(hold.status, "held");
});

test("capture debits once and writes one ledger entry", () => {
  setup();
  const hold = authorizeHold({ idempotencyKey: "h1", accountId: "A", amountCents: 200 });
  captureHold({ holdId: hold.id });
  captureHold({ holdId: hold.id });
  assert.strictEqual(balance("A"), 800);
  assert.strictEqual(available("A"), 800);
  assert.deepStrictEqual(ledger("A"), [{ holdId: hold.id, accountId: "A", amountCents: -200, kind: "capture" }]);
});

test("release frees the hold without a ledger entry", () => {
  setup();
  const hold = authorizeHold({ idempotencyKey: "h1", accountId: "A", amountCents: 200 });
  releaseHold({ holdId: hold.id });
  releaseHold({ holdId: hold.id });
  assert.strictEqual(available("A"), 1000);
  assert.strictEqual(balance("A"), 1000);
  assert.deepStrictEqual(ledger("A"), []);
});

test("holds cannot exceed available funds", () => {
  setup();
  authorizeHold({ idempotencyKey: "h1", accountId: "A", amountCents: 800 });
  assert.throws(() => authorizeHold({ idempotencyKey: "h2", accountId: "A", amountCents: 300 }),
    { message: "insufficient_funds" });
  assert.strictEqual(available("A"), 200);
});

test("authorize is idempotent and different keys make different holds", () => {
  setup();
  const first = authorizeHold({ idempotencyKey: "same", accountId: "A", amountCents: 100 });
  const second = authorizeHold({ idempotencyKey: "same", accountId: "A", amountCents: 100 });
  assert.deepStrictEqual(second, first);
  assert.strictEqual(available("A"), 900);
  const third = authorizeHold({ idempotencyKey: "other", accountId: "A", amountCents: 100 });
  assert.notStrictEqual(third.id, first.id);
  assert.strictEqual(available("A"), 800);
});

test("refund credits once and the capture/refund entries net to zero", () => {
  setup();
  const hold = authorizeHold({ idempotencyKey: "h1", accountId: "A", amountCents: 200 });
  captureHold({ holdId: hold.id });
  refund({ holdId: hold.id });
  refund({ holdId: hold.id });
  assert.strictEqual(balance("A"), 1000);
  const entries = ledger("A");
  assert.deepStrictEqual(entries.map((e) => e.amountCents), [-200, 200]);
  assert.strictEqual(entries.reduce((sum, e) => sum + e.amountCents, 0), 0);
});

test("invalid state transitions fail", () => {
  setup();
  const hold = authorizeHold({ idempotencyKey: "h1", accountId: "A", amountCents: 200 });
  releaseHold({ holdId: hold.id });
  assert.throws(() => captureHold({ holdId: hold.id }), { message: /hold_not_active/ });
  assert.throws(() => refund({ holdId: hold.id }), { message: /hold_not_captured/ });

  const captured = authorizeHold({ idempotencyKey: "h2", accountId: "A", amountCents: 100 });
  captureHold({ holdId: captured.id });
  assert.throws(() => releaseHold({ holdId: captured.id }), { message: /hold_not_active/ });
});

test("unknown ids and validation", () => {
  setup();
  assert.throws(() => authorizeHold({ idempotencyKey: "h1", accountId: "X", amountCents: 1 }),
    { message: "account_not_found: X" });
  assert.throws(() => authorizeHold({ idempotencyKey: "", accountId: "A", amountCents: 1 }),
    { message: /invalid_idempotency_key/ });
  assert.throws(() => authorizeHold({ idempotencyKey: "h1", accountId: "A", amountCents: 0 }),
    { message: "invalid_amount" });
  assert.throws(() => captureHold({ holdId: "X" }), { message: "hold_not_found: X" });
  assert.throws(() => balance("X"), { message: "account_not_found: X" });
});

test("concurrent holds never exceed available", async () => {
  setup();
  const results = await Promise.allSettled(
    Array.from({ length: 6 }, (_, i) =>
      Promise.resolve().then(() =>
        authorizeHold({ idempotencyKey: `c${i}`, accountId: "A", amountCents: 200 }))),
  );
  assert.strictEqual(results.filter((r) => r.status === "fulfilled").length, 5);
  assert.strictEqual(available("A"), 0);
});
