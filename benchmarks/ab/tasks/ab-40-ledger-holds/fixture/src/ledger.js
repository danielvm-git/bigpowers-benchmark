const accounts = new Map();
const holds = new Map();
let nextHold = 1;
export function reset() { accounts.clear(); holds.clear(); nextHold = 1; }
export function createAccount({ id, balanceCents, currency = "EUR" }) { const a = { id, balanceCents, currency }; accounts.set(id, a); return { ...a }; }
export function authorizeHold({ accountId, amountCents }) { const a = accounts.get(accountId); a.balanceCents -= amountCents; const h = { id: `H-${nextHold++}`, accountId, amountCents, status: "held" }; holds.set(h.id, h); return { ...h }; }
export function captureHold({ holdId }) { const h = holds.get(holdId); h.status = "captured"; return { ...h }; }
export function releaseHold({ holdId }) { const h = holds.get(holdId); h.status = "released"; return { ...h }; }
export function refund({ holdId }) { const h = holds.get(holdId); h.status = "refunded"; return { ...h }; }
export function balance(accountId) { return accounts.get(accountId).balanceCents; }
export function available(accountId) { return balance(accountId); }
export function ledger() { return []; }
