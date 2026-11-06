# Specification: loans and simple interest

## API

- `createLoan({ id, principalCents, annualRateBps, termMonths })`
- `accrueInterest({ loanId, days })`
- `repay({ loanId, amountCents })`
- `loanStatus({ loanId })`
- `reset()`

## Rules

1. **Loan.** Unique id; principal is a positive integer; rate is an integer 0–10000 basis points;
   term is a positive integer. A duplicate id fails with `duplicate_loan: <id>`. The loan starts
   `active` with the principal as balance.
2. **Interest.** Simple interest on the current balance:
   `round(balanceCents * annualRateBps / 10000 * days / 365)`. `days` is a non-negative integer.
   Interest increases the balance and `interestAccruedCents`.
3. **Repayment.** Amount is a positive integer. Overpaying fails with `overpayment`; paying the
   exact balance marks the loan `paid`; a paid loan rejects further repayment or interest with
   `loan_paid`.
4. **Status.** `loanStatus` returns the loan fields including `balanceCents`,
   `interestAccruedCents`, `paidCents` and `status`.
5. **Unknown loan.** `loan_not_found: <id>`.

## Invariants

- Existing tests in `test/loans.test.js` keep passing.
- A rejected repayment never changes the balance.
