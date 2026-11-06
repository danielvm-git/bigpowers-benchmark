const loans = new Map();
export function reset() { loans.clear(); }
function fail(code) { throw new Error(code); }
function requireLoan(id) { const loan = loans.get(id); if (!loan) fail(`loan_not_found: ${id}`); return loan; }
export function createLoan({ id, principalCents, annualRateBps, termMonths }) {
  if (typeof id !== "string" || !id) fail("invalid_loan_id");
  if (loans.has(id)) fail(`duplicate_loan: ${id}`);
  if (!Number.isInteger(principalCents) || principalCents <= 0) fail("invalid_principal");
  if (!Number.isInteger(annualRateBps) || annualRateBps < 0 || annualRateBps > 10000) fail("invalid_rate");
  if (!Number.isInteger(termMonths) || termMonths <= 0) fail("invalid_term");
  const loan = { id, principalCents, balanceCents: principalCents, annualRateBps, termMonths, status: "active", interestAccruedCents: 0, paidCents: 0 };
  loans.set(id, loan); return { ...loan };
}
export function accrueInterest({ loanId, days }) {
  const loan = requireLoan(loanId);
  if (loan.status === "paid") fail("loan_paid");
  if (!Number.isInteger(days) || days < 0) fail("invalid_days");
  const interestCents = Math.round((loan.balanceCents * loan.annualRateBps) / 10000 * days / 365);
  loan.balanceCents += interestCents; loan.interestAccruedCents += interestCents;
  return { interestCents, balanceCents: loan.balanceCents };
}
export function repay({ loanId, amountCents }) {
  const loan = requireLoan(loanId);
  if (loan.status === "paid") fail("loan_paid");
  if (!Number.isInteger(amountCents) || amountCents <= 0) fail("invalid_amount");
  if (amountCents > loan.balanceCents) fail("overpayment");
  loan.balanceCents -= amountCents; loan.paidCents += amountCents;
  if (loan.balanceCents === 0) loan.status = "paid";
  return { ...loan };
}
export function loanStatus({ loanId }) { return { ...requireLoan(loanId) }; }
