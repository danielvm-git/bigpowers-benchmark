const invoices = new Map(); const payments = new Map();
export function reset() { invoices.clear(); payments.clear(); }
export function addInvoice({ id, customer, amountCents, dueDay }) {
  invoices.set(id, { id, customer, amountCents, dueDay, paidCents: 0, status: "open" });
}
export function addPayment({ id, customer, amountCents, day }) {
  payments.set(id, { id, customer, amountCents, day, remaining: amountCents });
}
export function applyPayments({ customer }) {
  const invoice = [...invoices.values()].find((item) => item.customer === customer && item.status === "open");
  const payment = [...payments.values()].find((item) => item.customer === customer && item.remaining > 0);
  if (!invoice || !payment) return [];
  const amountCents = Math.min(invoice.amountCents, payment.remaining);
  invoice.paidCents += amountCents; payment.remaining -= amountCents;
  invoice.status = "paid";
  return [{ invoiceId: invoice.id, paymentId: payment.id, amountCents }];
}
export function dispute({ invoiceId }) { invoices.get(invoiceId).status = "disputed"; }
export function invoice(id) { return invoices.get(id); }
export function payment(id) { return payments.get(id); }
export function summary({ customer }) {
  return { openCents: 0, creditCents: 0, invoices: [] };
}
