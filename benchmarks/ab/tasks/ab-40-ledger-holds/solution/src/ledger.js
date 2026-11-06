const accounts = new Map();
const holds = new Map();
const idempotency = new Map();
const entries = [];
let nextHold = 1;
export function reset() { accounts.clear(); holds.clear(); idempotency.clear(); entries.length = 0; nextHold = 1; }
function fail(code) { throw new Error(code); }
function requireAccount(id) { const a = accounts.get(id); if (!a) fail(`account_not_found: ${id}`); return a; }
function requireHold(id) { const h = holds.get(id); if (!h) fail(`hold_not_found: ${id}`); return h; }
function activeHeld(accountId) {
  return [...holds.values()].filter((h) => h.accountId === accountId && h.status === "held")
    .reduce((sum, h) => sum + h.amountCents, 0);
}

export function createAccount({ id, balanceCents, currency = "EUR" }) {
  if (typeof id !== "string" || !id) fail("invalid_account_id");
  if (accounts.has(id)) fail(`duplicate_account: ${id}`);
  if (!Number.isInteger(balanceCents) || balanceCents < 0) fail("invalid_balance");
  const account = { id, balanceCents, currency }; accounts.set(id, account); return { ...account };
}
export function authorizeHold({ idempotencyKey, accountId, amountCents }) {
  const account = requireAccount(accountId);
  if (typeof idempotencyKey !== "string" || !idempotencyKey.trim()) fail("invalid_idempotency_key");
  if (idempotency.has(idempotencyKey)) return { ...idempotency.get(idempotencyKey) };
  if (!Number.isInteger(amountCents) || amountCents <= 0) fail("invalid_amount");
  if (account.balanceCents - activeHeld(accountId) < amountCents) fail("insufficient_funds");
  const hold = { id: `H-${nextHold++}`, accountId, amountCents, status: "held" };
  holds.set(hold.id, hold); idempotency.set(idempotencyKey, hold); return { ...hold };
}
export function captureHold({ holdId }) {
  const hold = requireHold(holdId);
  if (hold.status === "captured") return { ...hold };
  if (hold.status !== "held") fail("hold_not_active");
  hold.status = "captured";
  const account = requireAccount(hold.accountId);
  account.balanceCents -= hold.amountCents;
  entries.push({ holdId, accountId: hold.accountId, amountCents: -hold.amountCents, kind: "capture" });
  return { ...hold };
}
export function releaseHold({ holdId }) {
  const hold = requireHold(holdId);
  if (hold.status === "released") return { ...hold };
  if (hold.status !== "held") fail("hold_not_active");
  hold.status = "released"; return { ...hold };
}
export function refund({ holdId }) {
  const hold = requireHold(holdId);
  if (hold.status === "refunded") return { ...hold };
  if (hold.status !== "captured") fail("hold_not_captured");
  hold.status = "refunded";
  const account = requireAccount(hold.accountId);
  account.balanceCents += hold.amountCents;
  entries.push({ holdId, accountId: hold.accountId, amountCents: hold.amountCents, kind: "refund" });
  return { ...hold };
}
export function balance(accountId) { return requireAccount(accountId).balanceCents; }
export function available(accountId) { const a = requireAccount(accountId); return a.balanceCents - activeHeld(accountId); }
export function ledger(accountId) { requireAccount(accountId); return entries.filter((e) => e.accountId === accountId).map((e) => ({ ...e })); }
