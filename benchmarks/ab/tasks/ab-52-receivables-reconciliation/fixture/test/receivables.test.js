import test from "node:test";
import assert from "node:assert";
import { reset, addInvoice, addPayment, applyPayments, invoice } from "../src/receivables.js";

test("a payment pays an invoice", () => {
  reset();
  addInvoice({ id: "i1", customer: "c", amountCents: 100, dueDay: 1 });
  addPayment({ id: "p1", customer: "c", amountCents: 100, day: 1 });
  applyPayments({ customer: "c" });
  assert.strictEqual(invoice("i1").status, "paid");
});
