function fail(code) { throw new Error(code); }
const invoices = new Map(); const payments = new Map();
export function reset() { invoices.clear(); payments.clear(); }
export function addInvoice({ id, customer, amountCents, dueDay }) {
  if (invoices.has(id)) fail(`duplicate_invoice: ${id}`);
  if (typeof customer !== "string" || !customer || !Number.isInteger(amountCents)
    || amountCents <= 0 || !Number.isInteger(dueDay)) fail("invalid_invoice");
  invoices.set(id, { id, customer, amountCents, dueDay, paidCents: 0, status: "open" });
}
export function addPayment({ id, customer, amountCents, day }) {
  if (payments.has(id)) fail(`duplicate_payment: ${id}`);
  if (typeof customer !== "string" || !customer || !Number.isInteger(amountCents)
    || amountCents <= 0 || !Number.isInteger(day)) fail("invalid_payment");
  payments.set(id, { id, customer, amountCents, day, remaining: amountCents });
}
export function applyPayments({ customer }) {
  const open = [...invoices.values()].filter((item) => item.customer === customer
    && item.status === "open" && item.paidCents < item.amountCents)
    .sort((a, b) => a.dueDay - b.dueDay || a.id.localeCompare(b.id));
  const funds = [...payments.values()].filter((item) => item.customer === customer && item.remaining > 0)
    .sort((a, b) => a.day - b.day || a.id.localeCompare(b.id));
  const allocations = [];
  for (const invoiceItem of open) {
    let owed = invoiceItem.amountCents - invoiceItem.paidCents;
    for (const paymentItem of funds) {
      if (!owed) break;
      if (paymentItem.remaining <= 0) continue;
      const amountCents = Math.min(owed, paymentItem.remaining);
      invoiceItem.paidCents += amountCents; paymentItem.remaining -= amountCents; owed -= amountCents;
      allocations.push({ invoiceId: invoiceItem.id, paymentId: paymentItem.id, amountCents });
      if (invoiceItem.paidCents === invoiceItem.amountCents) invoiceItem.status = "paid";
    }
  }
  return allocations;
}
export function dispute({ invoiceId }) {
  const current = invoices.get(invoiceId);
  if (!current) fail(`invoice_not_found: ${invoiceId}`);
  if (current.status === "paid") fail("invoice_paid");
  current.status = "disputed";
  return current;
}
export function invoice(id) { return invoices.get(id); }
export function payment(id) { return payments.get(id); }
export function summary({ customer }) {
  const items = [...invoices.values()].filter((item) => item.customer === customer)
    .sort((a, b) => a.dueDay - b.dueDay || a.id.localeCompare(b.id));
  return {
    openCents: items.filter((item) => item.status === "open")
      .reduce((sum, item) => sum + item.amountCents - item.paidCents, 0),
    creditCents: [...payments.values()].filter((item) => item.customer === customer)
      .reduce((sum, item) => sum + item.remaining, 0),
    invoices: items,
  };
}
