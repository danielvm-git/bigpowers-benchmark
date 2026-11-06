import test from "node:test";
import assert from "node:assert";
import { accrueInterest, createLoan, loanStatus, repay, reset } from "../src/loans.js";
test("accrues interest and repays", () => {
  reset();
  createLoan({ id: "L1", principalCents: 100000, annualRateBps: 1000, termMonths: 12 });
  accrueInterest({ loanId: "L1", days: 365 });
  repay({ loanId: "L1", amountCents: 10000 });
  assert.strictEqual(loanStatus({ loanId: "L1" }).balanceCents, 100000);
});
