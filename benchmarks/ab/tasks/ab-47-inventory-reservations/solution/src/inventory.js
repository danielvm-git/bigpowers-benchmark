function fail(code) { throw new Error(code); }
const state = { items: new Map(), reservations: new Map(), nextId: 1 };
export function reset() { state.items.clear(); state.reservations.clear(); state.nextId = 1; }
export function addItem({ sku, stock }) {
  if (!Number.isInteger(stock) || stock < 0) fail(`invalid_item: ${sku}`);
  if (state.items.has(sku)) fail(`duplicate_item: ${sku}`);
  state.items.set(sku, { sku, stock });
}
function itemOrFail(sku) { const item = state.items.get(sku); if (!item) fail(`item_not_found: ${sku}`); return item; }
function reservationOrFail(id) {
  const reservation = state.reservations.get(id);
  if (!reservation) fail(`reservation_not_found: ${id}`);
  return reservation;
}
function active(reservation, now) {
  return reservation.status === "pending" && now < reservation.expiresAt;
}
export function available(sku, now) {
  const item = itemOrFail(sku);
  let held = 0;
  for (const reservation of state.reservations.values()) {
    if (reservation.sku === sku && active(reservation, now)) held += reservation.qty;
  }
  return item.stock - held;
}
export function reserve({ sku, qty, now, ttl }) {
  if (!Number.isInteger(qty) || qty <= 0 || !Number.isInteger(ttl) || ttl <= 0) {
    fail(`invalid_reservation: ${sku}`);
  }
  if (available(sku, now) < qty) fail(`insufficient_stock: ${sku}`);
  const id = `r${state.nextId++}`;
  const reservation = { id, sku, qty, status: "pending", expiresAt: now + ttl };
  state.reservations.set(id, reservation);
  return { id };
}
function pendingOrFail(id, now) {
  const reservation = reservationOrFail(id);
  if (now >= reservation.expiresAt) fail("reservation_expired");
  if (reservation.status !== "pending") fail("reservation_not_pending");
  return reservation;
}
export function confirm({ id, now }) {
  const reservation = pendingOrFail(id, now);
  const item = itemOrFail(reservation.sku);
  if (item.stock < reservation.qty) fail(`insufficient_stock: ${reservation.sku}`);
  item.stock -= reservation.qty; reservation.status = "confirmed";
  return reservation;
}
export function cancel({ id, now }) {
  const reservation = pendingOrFail(id, now);
  reservation.status = "cancelled";
  return reservation;
}
export function sweep(now) {
  let count = 0;
  for (const reservation of state.reservations.values()) {
    if (reservation.status === "pending" && now >= reservation.expiresAt) {
      reservation.status = "expired"; count += 1;
    }
  }
  return count;
}
export function reservation(id) { return state.reservations.get(id); }
