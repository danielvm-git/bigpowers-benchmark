# Specification: Payment Alias Registry

## Overview

An account can link payment keys so a payer can be identified by CPF, CNPJ, phone, email or an
EVP random key. A key belongs to exactly one account.

## Key types and acceptance

| Type | Accepted | Rejected |
|---|---|---|
| `cpf` | 11 digits with valid check digits, e.g. `52998224725` | wrong length, bad check digit, repeated digits such as `11111111111` |
| `cnpj` | 14 digits with valid check digits, e.g. `11222333000181` | wrong length, repeated digits, bad check digits |
| `phone` | E.164: `+` followed by 10 to 14 digits, e.g. `+5511987654321` | missing `+`, too short, letters |
| `email` | one `@`, non-empty local part, domain containing a dot, e.g. `Ana.Lima@Example.COM` | missing `@`, missing dot in the domain |
| `evp` | UUID v4, e.g. `9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d` | malformed UUID, wrong version |

Emails and EVP keys are stored lowercased. CPF and CNPJ are stored as digits.

Errors are observable:

- `invalid <type> key: <key>` for a rejected key;
- `unsupported key type: <type>` for an unknown type;
- `account not found: <id>` for an unknown account;
- `alias already registered: <key>` for a duplicate key;
- `account quota exceeded: max <n> aliases for <type> account` when the account is full.

## Account quotas

- `personal`: at most **5** aliases.
- `business`: at most **20** aliases.

The quota is checked against that account only. A key is globally unique across every account.

## API

- `registerAlias(accountId, type, key)` validates the account and key, enforces uniqueness and the
  quota, then returns `{ accountId, type, key, createdAt }`.
- `listAliases(accountId)` returns that account's aliases in registration order. An
  unknown account returns an empty list rather than throwing.
- `resetAliases()` clears the registry for tests.

## Invariants

- Existing tests in `test/accounts.test.js` keep passing.
- A failed registration leaves the registry unchanged, including the global uniqueness set.
