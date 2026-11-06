import test from "node:test";
import assert from "node:assert";
import { accrueInterest, createLoan, loanStatus, repay, reset } from "../src/loans.js";

function loan(overrides = {}) {
  createLoan({ id: "L1", principalCents: 100000, annualRateBps: 1000, termMonths: 12, ...overrides });
}
function fresh(overrides) { reset(); loan(overrides); }

test("simple interest uses days and the 365-day year", () => {
  fresh();
  assert.deepStrictEqual(accrueInterest({ loanId: "L1", days: 365 }),
    { interestCents: 10000, balanceCents: 110000 });
  assert.deepStrictEqual(accrueInterest({ loanId: "L1", days: 365 }),
    { interestCents: 11000, balanceCents: 121000 });
  assert.strictEqual(loanStatus({ loanId: "L1" }).interestAccruedCents, 21000);
});

test("zero days and zero rate accrue nothing", () => {
  fresh();
  assert.deepStrictEqual(accrueInterest({ loanId: "L1", days: 0 }),
    { interestCents: 0, balanceCents: 100000 });
  fresh({ annualRateBps: 0 });
  assert.deepStrictEqual(accrueInterest({ loanId: "L1", days: 365 }),
    { interestCents: 0, balanceCents: 100000 });
});

test("repayment reduces the balance and exact repayment marks paid", () => {
  fresh();
  assert.strictEqual(repay({ loanId: "L1", amountCents: 40000 }).balanceCents, 60000);
  assert.strictEqual(loanStatus({ loanId: "L1" }).paidCents, 40000);
  const paid = repay({ loanId: "L1", amountCents: 60000 });
  assert.strictEqual(paid.status, "paid");
  assert.strictEqual(paid.balanceCents, 0);
});

test("overpayment and post-paid operations fail without mutation", () => {
  fresh();
  assert.throws(() => repay({ loanId: "L1", amountCents: 100001 }), { message: "overpayment" });
  assert.strictEqual(loanStatus({ loanId: "L1" }).balanceCents, 100000);
  repay({ loanId: "L1", amountCents: 100000 });
  assert.throws(() => repay({ loanId: "L1", amountCents: 1 }), { message: "loan_paid" });
  assert.throws(() => accrueInterest({ loanId: "L1", days: 1 }), { message: "loan_paid" });
});

test("interest after a repayment uses the reduced balance", () => {
  fresh();
  repay({ loanId: "L1", amountCents: 50000 });
  assert.deepStrictEqual(accrueInterest({ loanId: "L1", days: 365 }),
    { interestCents: 5000, balanceCents: 55000 });
});

test("unknown loans and validation", () => {
  reset();
  assert.throws(() => loanStatus({ loanId: "X" }), { message: "loan_not_found: X" });
  assert.throws(() => createLoan({ id: "L1", principalCents: 0, annualRateBps: 1, termMonths: 1 }),
    { message: "invalid_principal" });
  assert.throws(() => createLoan({ id: "L1", principalCents: 1, annualRateBps: 10001, termMonths: 1 }),
    { message: "invalid_rate" });
  fresh();
  assert.throws(() => accrueInterest({ loanId: "L1", days: -1 }), { message: "invalid_days" });
  assert.throws(() => repay({ loanId: "L1", amountCents: 0 }), { message: "invalid_amount" });
  assert.throws(() => createLoan({ id: "L1", principalCents: 1, annualRateBps: 1, termMonths: 1 }),
    { message: "duplicate_loan: L1" });
});
