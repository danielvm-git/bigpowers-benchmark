# Specification: banking ledger

## Overview

An in-memory bank with accounts, transfers and a double-entry ledger.

## API

- `createAccount({ id, owner, currency = "EUR", balanceCents = 0 })`
- `transfer({ idempotencyKey, from, to, amountCents })`
- `balance(accountId)`
- `ledger(accountId)`
- `reset()`

## Rules

1. **Accounts.** `id` is unique and non-empty; `balanceCents` is a non-negative integer;
   `currency` is a string. A duplicate id fails with `duplicate_account: <id>`.
2. **Transfer validation.** `idempotencyKey` is a non-empty string; `from` and `to` must exist;
   they must differ; `amountCents` is a positive integer; both accounts must use the same currency.
   Errors: `invalid_idempotency_key`, `account_not_found: <id>`, `same_account`,
   `invalid_amount`, `currency_mismatch`, `insufficient_funds`.
3. **Atomicity.** A rejected transfer changes no balance and writes no ledger entry.
4. **Idempotency.** The same key returns the original transfer result and applies the money once.
   A different key is a new transfer.
5. **Double entry.** Every successful transfer appends exactly two entries:
   `-amount` on the source and `+amount` on the destination, with the same transfer id.
   The sum of all ledger entries is always zero.
6. **Ledger.** `ledger(accountId)` returns that account's entries in write order. An unknown
   account fails with `account_not_found: <id>`.
7. **Concurrency.** Concurrent transfers must not overdraw an account or lose an update.

## Invariants

- Existing tests in `test/bank.test.js` keep passing.
- `balance(id)` equals the account balance and the sum of its ledger entries.
