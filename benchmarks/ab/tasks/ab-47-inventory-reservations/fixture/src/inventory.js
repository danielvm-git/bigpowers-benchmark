const state = { items: new Map(), reservations: new Map(), nextId: 1 };
export function reset() { state.items.clear(); state.reservations.clear(); state.nextId = 1; }
export function addItem({ sku, stock }) {
  state.items.set(sku, { sku, stock });
}
export function available(sku) {
  const item = state.items.get(sku);
  return item.stock;
}
export function reserve({ sku, qty, now, ttl }) {
  const id = `r${state.nextId++}`;
  state.reservations.set(id, { id, sku, qty, status: "pending", expiresAt: now + ttl });
  return { id };
}
export function confirm({ id, now }) {
  const reservation = state.reservations.get(id);
  reservation.status = "confirmed";
  state.items.get(reservation.sku).stock -= reservation.qty;
  return reservation;
}
export function cancel({ id }) {
  const reservation = state.reservations.get(id);
  reservation.status = "cancelled";
  return reservation;
}
export function sweep() { return 0; }
export function reservation(id) { return state.reservations.get(id); }
