const state = { warehouses: new Map(), stock: new Map(), orders: new Map() };
export function reset() { state.warehouses.clear(); state.stock.clear(); state.orders.clear(); }
export function addWarehouse({ id, priority }) { state.warehouses.set(id, { id, priority }); }
export function setStock({ warehouseId, sku, qty }) { state.stock.set(`${warehouseId}:${sku}`, qty); }
function stockOf(warehouseId, sku) { return state.stock.get(`${warehouseId}:${sku}`) ?? 0; }
export function available(sku) {
  let total = 0;
  for (const id of state.warehouses.keys()) total += stockOf(id, sku);
  return total;
}
export function placeOrder({ id, items }) {
  const allocations = [];
  let backordered = 0;
  for (const item of items) {
    let remaining = item.qty;
    for (const warehouse of state.warehouses.values()) {
      const take = Math.min(remaining, stockOf(warehouse.id, item.sku));
      if (take) { allocations.push({ sku: item.sku, warehouseId: warehouse.id, qty: take }); remaining -= take; }
    }
    backordered += remaining;
  }
  state.orders.set(id, { id, allocations, backordered, status: backordered ? "backordered" : "allocated" });
  return state.orders.get(id);
}
export function fulfill({ id }) { const current = state.orders.get(id); current.status = "fulfilled"; return current; }
export function cancel({ id }) { const current = state.orders.get(id); current.status = "cancelled"; return current; }
export function order(id) { return state.orders.get(id); }
