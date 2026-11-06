const accounts = new Map();
const entries = [];

export function reset() {
  accounts.clear();
  entries.length = 0;
}

export function createAccount({ id, owner, currency = "EUR", balanceCents = 0 }) {
  const account = { id, owner, currency, balanceCents };
  accounts.set(id, account);
  return { ...account };
}

export function balance(accountId) {
  return accounts.get(accountId).balanceCents;
}

export function transfer({ from, to, amountCents }) {
  const source = accounts.get(from);
  const target = accounts.get(to);
  source.balanceCents -= amountCents;
  target.balanceCents += amountCents;
  return { from, to, amountCents };
}

export function ledger(accountId) {
  return entries.filter((entry) => entry.accountId === accountId);
}
