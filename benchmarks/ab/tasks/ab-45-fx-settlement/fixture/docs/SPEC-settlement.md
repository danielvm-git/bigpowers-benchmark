# Specification: FX settlement

## API

`settle(entries, config)` returns `{ totalBaseCents, byAccount }`.

- `entries`: `{ account, currency, amountCents }`; `amountCents` is a signed integer
  (positive credit, negative debit).
- `config`: `{ base, rates }`; `rates` maps each currency to a positive integer number of
  base minor units per 10,000 currency minor units.

## Rules

1. **Conversion.** `amountCents * rate / 10000`, rounded half away from zero.
2. **Base.** The base currency must have rate `10000`; otherwise fail with `invalid_base_rate`.
3. **Aggregation.** Sum converted amounts per account and `totalBaseCents`. `byAccount` is
   `[{ account, baseCents }]` sorted by account.
4. **Validation.** Unknown currency fails with `unknown_rate: <currency>`; a non-integer amount
   fails with `invalid_amount`; a non-positive integer rate fails with `invalid_rate: <currency>`.
5. Empty entries return zero totals and an empty `byAccount`.

## Invariants

- Existing tests in `test/settlement.test.js` keep passing.
- Rounding is symmetric around zero.
