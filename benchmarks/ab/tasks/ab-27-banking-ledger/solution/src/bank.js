const accounts = new Map();
const entries = [];
const transfers = new Map();
let nextTransferId = 1;

export function reset() {
  accounts.clear();
  entries.length = 0;
  transfers.clear();
  nextTransferId = 1;
}

function fail(code) {
  throw new Error(code);
}

function requireAccount(id) {
  const account = accounts.get(id);
  if (!account) fail(`account_not_found: ${id}`);
  return account;
}

export function createAccount({ id, owner, currency = "EUR", balanceCents = 0 }) {
  if (typeof id !== "string" || !id) fail("invalid_account_id");
  if (accounts.has(id)) fail(`duplicate_account: ${id}`);
  if (!Number.isInteger(balanceCents) || balanceCents < 0) fail("invalid_balance");
  const account = { id, owner, currency, balanceCents };
  accounts.set(id, account);
  return { ...account };
}

export function balance(accountId) {
  return requireAccount(accountId).balanceCents;
}

export function transfer({ idempotencyKey, from, to, amountCents }) {
  if (typeof idempotencyKey !== "string" || !idempotencyKey.trim()) fail("invalid_idempotency_key");
  if (transfers.has(idempotencyKey)) return { ...transfers.get(idempotencyKey) };

  const source = requireAccount(from);
  const target = requireAccount(to);
  if (from === to) fail("same_account");
  if (!Number.isInteger(amountCents) || amountCents <= 0) fail("invalid_amount");
  if (source.currency !== target.currency) fail("currency_mismatch");
  if (source.balanceCents < amountCents) fail("insufficient_funds");

  source.balanceCents -= amountCents;
  target.balanceCents += amountCents;
  const transfer = {
    id: `TX-${nextTransferId++}`,
    from,
    to,
    amountCents,
    currency: source.currency,
  };
  entries.push(
    { transferId: transfer.id, accountId: from, amountCents: -amountCents },
    { transferId: transfer.id, accountId: to, amountCents },
  );
  transfers.set(idempotencyKey, transfer);
  return { ...transfer };
}

export function ledger(accountId) {
  requireAccount(accountId);
  return entries.filter((entry) => entry.accountId === accountId).map((entry) => ({ ...entry }));
}
