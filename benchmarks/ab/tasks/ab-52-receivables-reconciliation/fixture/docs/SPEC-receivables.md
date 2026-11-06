# Specification: receivables reconciliation

## API

`reset()`, `addInvoice({ id, customer, amountCents, dueDay })`,
`addPayment({ id, customer, amountCents, day })`, `applyPayments({ customer })`,
`dispute({ invoiceId })`, `invoice(id)`, `payment(id)`, `summary({ customer })`.

## Rules

1. **Invoices.** Unique id; `amountCents` is a positive integer; `dueDay` is an integer.
   Duplicate fails with `duplicate_invoice: <id>`; invalid values with `invalid_invoice`.
2. **Payments.** Unique id; `amountCents` is a positive integer; `day` is an integer.
   Duplicate fails with `duplicate_payment: <id>`; invalid values with `invalid_payment`.
3. **Allocation.** For one customer, apply payments in `day` then `id` order to open,
   non-disputed invoices in `dueDay` then `id` order. Each invoice receives at most its
   unpaid amount; payments keep any remainder as credit. An invoice becomes `paid` when
   `paidCents == amountCents`.
4. **Disputes.** Only an open invoice can be disputed; it becomes `disputed` and is skipped
   by later allocations. A paid invoice fails with `invoice_paid`; unknown fails with
   `invoice_not_found: <id>`.
5. **Summary.** `summary({ customer })` returns
   `{ openCents, creditCents, invoices }`, where `invoices` is a copy of that customer's
   invoices sorted by `dueDay` then `id`, and `creditCents` is the sum of unallocated
   payment remainders.
6. **Isolation.** Payments only pay invoices for the same customer.

## Invariants

- Existing tests in `test/receivables.test.js` keep passing.
- Allocation never overpays an invoice and never loses payment cents.
