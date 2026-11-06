import test from "node:test";
import assert from "node:assert";
import { reset, addInvoice, addPayment, applyPayments, dispute, invoice, payment, summary }
  from "../src/receivables.js";

function base() {
  reset();
  addInvoice({ id: "i2", customer: "c", amountCents: 100, dueDay: 2 });
  addInvoice({ id: "i1", customer: "c", amountCents: 50, dueDay: 1 });
  addInvoice({ id: "i3", customer: "c", amountCents: 30, dueDay: 2 });
}

test("allocates FIFO by due day then id", () => {
  base(); addPayment({ id: "p1", customer: "c", amountCents: 120, day: 1 });
  const allocations = applyPayments({ customer: "c" });
  assert.deepStrictEqual(allocations, [
    { invoiceId: "i1", paymentId: "p1", amountCents: 50 },
    { invoiceId: "i2", paymentId: "p1", amountCents: 70 },
  ]);
  assert.strictEqual(invoice("i2").status, "open");
  assert.strictEqual(payment("p1").remaining, 0);
});

test("partial payments leave invoices open", () => {
  base(); addPayment({ id: "p1", customer: "c", amountCents: 20, day: 1 });
  applyPayments({ customer: "c" });
  assert.strictEqual(invoice("i1").paidCents, 20);
  assert.strictEqual(invoice("i1").status, "open");
});

test("overpayments remain as credit", () => {
  base(); addPayment({ id: "p1", customer: "c", amountCents: 500, day: 1 });
  applyPayments({ customer: "c" });
  assert.strictEqual(summary({ customer: "c" }).creditCents, 320);
  assert.strictEqual(summary({ customer: "c" }).openCents, 0);
});

test("multiple payments are applied in day then id order", () => {
  base();
  addPayment({ id: "late", customer: "c", amountCents: 50, day: 2 });
  addPayment({ id: "early", customer: "c", amountCents: 50, day: 1 });
  const allocations = applyPayments({ customer: "c" });
  assert.deepStrictEqual(allocations.map((item) => item.paymentId), ["early", "late"]);
});

test("disputed invoices are skipped", () => {
  base(); dispute({ invoiceId: "i1" });
  addPayment({ id: "p1", customer: "c", amountCents: 100, day: 1 });
  const allocations = applyPayments({ customer: "c" });
  assert.deepStrictEqual(allocations, [{ invoiceId: "i2", paymentId: "p1", amountCents: 100 }]);
  assert.strictEqual(invoice("i1").status, "disputed");
});

test("paid invoices cannot be disputed", () => {
  base(); addPayment({ id: "p1", customer: "c", amountCents: 50, day: 1 });
  applyPayments({ customer: "c" });
  assert.throws(() => dispute({ invoiceId: "i1" }), { message: "invoice_paid" });
});

test("customers are isolated", () => {
  base();
  addInvoice({ id: "x", customer: "other", amountCents: 100, dueDay: 1 });
  addPayment({ id: "p1", customer: "c", amountCents: 1000, day: 1 });
  applyPayments({ customer: "c" });
  assert.strictEqual(invoice("x").paidCents, 0);
});

test("summary sorts invoices and reports open cents", () => {
  base();
  const result = summary({ customer: "c" });
  assert.deepStrictEqual(result.invoices.map((item) => item.id), ["i1", "i2", "i3"]);
  assert.strictEqual(result.openCents, 180);
});

test("duplicates and invalid values fail", () => {
  base();
  assert.throws(() => addInvoice({ id: "i1", customer: "c", amountCents: 1, dueDay: 1 }),
    { message: "duplicate_invoice: i1" });
  assert.throws(() => addPayment({ id: "p1", customer: "c", amountCents: 0, day: 1 }),
    { message: "invalid_payment" });
  assert.throws(() => dispute({ invoiceId: "nope" }), { message: "invoice_not_found: nope" });
});

test("allocation loses no cents", () => {
  base();
  addPayment({ id: "p1", customer: "c", amountCents: 180, day: 1 });
  applyPayments({ customer: "c" });
  assert.strictEqual(payment("p1").remaining, 0);
  assert.strictEqual(summary({ customer: "c" }).openCents, 0);
});
