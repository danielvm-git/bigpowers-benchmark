const orders = new Map();
export function reset() { orders.clear(); }
export function createOrder({ id, items, totalCents }) {
  orders.set(id, { id, items, totalCents, status: "created", history: [] });
  return orders.get(id);
}
export function pay({ id, paymentId }) {
  const current = orders.get(id);
  current.status = "paid"; current.paymentId = paymentId;
  current.history.push({ action: "paid" });
  return current;
}
export function ship({ id, tracking }) {
  const current = orders.get(id);
  current.status = "shipped"; current.tracking = tracking;
  current.history.push({ action: "shipped" });
  return current;
}
export function cancel({ id }) {
  const current = orders.get(id);
  current.status = "cancelled";
  current.history.push({ action: "cancelled" });
  return current;
}
export function order(id) { return orders.get(id); }
