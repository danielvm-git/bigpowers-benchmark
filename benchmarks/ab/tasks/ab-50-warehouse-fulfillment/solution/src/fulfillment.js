function fail(code) { throw new Error(code); }
const state = { warehouses: new Map(), stock: new Map(), reserved: new Map(), orders: new Map() };
const key = (warehouseId, sku) => `${warehouseId}:${sku}`;
export function reset() {
  state.warehouses.clear(); state.stock.clear(); state.reserved.clear(); state.orders.clear();
}
export function addWarehouse({ id, priority }) {
  if (state.warehouses.has(id)) fail(`duplicate_warehouse: ${id}`);
  if (!Number.isInteger(priority)) fail(`invalid_warehouse: ${id}`);
  state.warehouses.set(id, { id, priority });
}
export function setStock({ warehouseId, sku, qty }) {
  if (!state.warehouses.has(warehouseId)) fail(`warehouse_not_found: ${warehouseId}`);
  if (!Number.isInteger(qty) || qty < 0) fail(`invalid_stock: ${sku}`);
  if (qty < (state.reserved.get(key(warehouseId, sku)) ?? 0)) fail("stock_below_reserved");
  state.stock.set(key(warehouseId, sku), qty);
}
function stockOf(warehouseId, sku) { return state.stock.get(key(warehouseId, sku)) ?? 0; }
function freeOf(warehouseId, sku) {
  return stockOf(warehouseId, sku) - (state.reserved.get(key(warehouseId, sku)) ?? 0);
}
export function available(sku) {
  let total = 0;
  for (const id of state.warehouses.keys()) total += freeOf(id, sku);
  return total;
}
function warehousesInOrder() {
  return [...state.warehouses.values()].sort((a, b) => a.priority - b.priority
    || a.id.localeCompare(b.id));
}
export function placeOrder({ id, items }) {
  if (state.orders.has(id)) fail(`duplicate_order: ${id}`);
  if (!Array.isArray(items) || !items.length) fail("invalid_order");
  const skus = new Set();
  for (const item of items) {
    if (!item || typeof item.sku !== "string" || !Number.isInteger(item.qty) || item.qty <= 0
      || skus.has(item.sku)) fail("invalid_order");
    skus.add(item.sku);
  }
  const allocations = []; let backordered = 0; let totalShortfall = 0;
  for (const item of items) {
    let remaining = item.qty;
    for (const warehouse of warehousesInOrder()) {
      const take = Math.min(remaining, freeOf(warehouse.id, item.sku));
      if (take) { allocations.push({ sku: item.sku, warehouseId: warehouse.id, qty: take }); remaining -= take; }
    }
    backordered += remaining; totalShortfall += remaining;
  }
  for (const allocation of allocations) {
    const stockKey = key(allocation.warehouseId, allocation.sku);
    state.reserved.set(stockKey, (state.reserved.get(stockKey) ?? 0) + allocation.qty);
  }
  const current = { id, allocations, backordered, status: totalShortfall ? "backordered" : "allocated" };
  state.orders.set(id, current);
  return current;
}
function get(id) { const current = state.orders.get(id); if (!current) fail(`order_not_found: ${id}`); return current; }
export function fulfill({ id }) {
  const current = get(id);
  if (current.status !== "allocated") fail("invalid_transition");
  for (const allocation of current.allocations) {
    const stockKey = key(allocation.warehouseId, allocation.sku);
    state.stock.set(stockKey, stockOf(allocation.warehouseId, allocation.sku) - allocation.qty);
    state.reserved.set(stockKey, state.reserved.get(stockKey) - allocation.qty);
  }
  current.allocations = []; current.status = "fulfilled";
  return current;
}
export function cancel({ id }) {
  const current = get(id);
  if (current.status !== "allocated" && current.status !== "backordered") fail("invalid_transition");
  for (const allocation of current.allocations) {
    const stockKey = key(allocation.warehouseId, allocation.sku);
    state.reserved.set(stockKey, state.reserved.get(stockKey) - allocation.qty);
  }
  current.allocations = []; current.status = "cancelled";
  return current;
}
export function order(id) { return state.orders.get(id); }
