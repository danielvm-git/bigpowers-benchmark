# Specification: ledger holds and refunds

## API

- `createAccount({ id, balanceCents, currency = "EUR" })`
- `authorizeHold({ idempotencyKey, accountId, amountCents })`
- `captureHold({ holdId })`
- `releaseHold({ holdId })`
- `refund({ holdId })`
- `balance(accountId)`
- `available(accountId)`
- `ledger(accountId)`
- `reset()`

## Rules

1. **Account.** Unique id; balance is a non-negative integer; currency is a string.
2. **Authorize.** Amount is a positive integer; the available balance
   (`balance - active holds`) must cover it; otherwise `insufficient_funds`.
   A missing or empty key fails with `invalid_idempotency_key`. The same key returns the original
   hold. A hold does not change the balance.
3. **Capture.** An active hold becomes `captured`, debits the balance once and appends a ledger
   entry `{ holdId, accountId, amountCents: -amount, kind: "capture" }`. Capturing twice is
   idempotent and never debits twice. A released/refunded hold fails with `hold_not_active`.
4. **Release.** An active hold becomes `released` and frees its amount; releasing twice is
   idempotent. A captured/refunded hold fails with `hold_not_active`.
5. **Refund.** A captured hold becomes `refunded`, credits the balance once and appends
   `{ holdId, accountId, amountCents: +amount, kind: "refund" }`. Refunding twice is idempotent.
   A non-captured hold fails with `hold_not_captured`.
6. **Errors.** Unknown account/hold: `account_not_found: <id>` / `hold_not_found: <id>`.
   Invalid amount: `invalid_amount`.

## Invariants

- Existing tests in `test/ledger.test.js` keep passing.
- The sum of a hold's ledger entries equals its net balance effect.
