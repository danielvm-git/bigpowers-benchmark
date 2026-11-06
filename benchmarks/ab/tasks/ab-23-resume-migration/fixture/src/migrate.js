import fs from "node:fs";
import path from "node:path";

export function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

export function writeJson(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 2));
}

export function normalizeOrders(orders) {
  return orders.map((order) => ({
    id: order.id,
    customerId: order.customerId,
    totalCents: order.items.reduce((sum, item) => sum + item.qty * item.unitCents, 0),
    itemCount: order.items.reduce((sum, item) => sum + item.qty, 0),
  }));
}

export function runMigration(dataDir) {
  const orders = readJson(path.join(dataDir, "orders.json"));
  const normalized = normalizeOrders(orders);
  writeJson(path.join(dataDir, "orders.normalized.json"), normalized);

  const customers = readJson(path.join(dataDir, "customers.json"));
  const index = Object.fromEntries(customers.map((customer) => [customer.id, customer]));
  writeJson(path.join(dataDir, "customers.index.json"), index);

  return { normalized, index };
}
