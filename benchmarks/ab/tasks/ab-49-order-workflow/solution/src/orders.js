function fail(code) { throw new Error(code); }
const orders = new Map();
export function reset() { orders.clear(); }
function get(id) { const current = orders.get(id); if (!current) fail(`order_not_found: ${id}`); return current; }
export function createOrder({ id, items, totalCents }) {
  if (orders.has(id)) fail(`duplicate_order: ${id}`);
  if (!Array.isArray(items) || !items.length || !Number.isInteger(totalCents) || totalCents <= 0) {
    fail("invalid_order");
  }
  const current = { id, items: [...items], totalCents, status: "created", history: [] };
  orders.set(id, current);
  return current;
}
export function pay({ id, paymentId }) {
  const current = get(id);
  if (current.status === "paid" && current.paymentId === paymentId) return current;
  if (current.status === "paid" && current.paymentId !== paymentId) fail("payment_conflict");
  if (current.status !== "created") fail("invalid_transition");
  current.status = "paid"; current.paymentId = paymentId;
  current.history.push({ action: "paid" });
  return current;
}
export function ship({ id, tracking }) {
  const current = get(id);
  if (current.status === "shipped" && current.tracking === tracking) return current;
  if (current.status !== "paid") fail("invalid_transition");
  current.status = "shipped"; current.tracking = tracking;
  current.history.push({ action: "shipped" });
  return current;
}
export function cancel({ id }) {
  const current = get(id);
  if (current.status !== "created" && current.status !== "paid") fail("invalid_transition");
  if (current.status === "paid") current.history.push({ action: "refunded" });
  current.status = "cancelled";
  current.history.push({ action: "cancelled" });
  return current;
}
export function order(id) { return orders.get(id); }
