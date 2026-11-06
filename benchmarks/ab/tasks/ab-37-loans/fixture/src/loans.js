const loans = new Map();
export function reset() { loans.clear(); }
export function createLoan({ id, principalCents, annualRateBps, termMonths }) {
  const loan = { id, principalCents, balanceCents: principalCents, annualRateBps, termMonths, status: "active", interestAccruedCents: 0, paidCents: 0 };
  loans.set(id, loan); return { ...loan };
}
export function accrueInterest({ loanId, days }) {
  const loan = loans.get(loanId);
  const interest = Math.round(loan.principalCents * 0.10);
  loan.balanceCents += interest; loan.interestAccruedCents += interest;
  return { interestCents: interest, balanceCents: loan.balanceCents };
}
export function repay({ loanId, amountCents }) {
  const loan = loans.get(loanId);
  loan.balanceCents -= amountCents; loan.paidCents += amountCents;
  return loanStatus({ loanId });
}
export function loanStatus({ loanId }) { return { ...loans.get(loanId) }; }
