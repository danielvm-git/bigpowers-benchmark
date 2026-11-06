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

const OUTPUTS = {
  1: "orders.normalized.json",
  2: "customers.index.json",
  3: "summary.json",
};

const STEPS = {
  1(dataDir) {
    const orders = readJson(path.join(dataDir, "orders.json"));
    writeJson(path.join(dataDir, OUTPUTS[1]), normalizeOrders(orders));
  },
  2(dataDir) {
    const customers = readJson(path.join(dataDir, "customers.json"));
    const index = Object.fromEntries(customers.map((customer) => [customer.id, customer]));
    writeJson(path.join(dataDir, OUTPUTS[2]), index);
  },
  3(dataDir) {
    const orders = readJson(path.join(dataDir, OUTPUTS[1]));
    const index = readJson(path.join(dataDir, OUTPUTS[2]));
    writeJson(path.join(dataDir, OUTPUTS[3]), {
      orderCount: orders.length,
      customerCount: Object.keys(index).length,
      revenueCents: orders.reduce((sum, order) => sum + order.totalCents, 0),
    });
  },
};

function loadState(dataDir) {
  const file = path.join(dataDir, "migration-state.json");
  if (!fs.existsSync(file)) return { version: 1, completedSteps: [] };
  const state = readJson(file);
  return { version: state.version ?? 1, completedSteps: Array.isArray(state.completedSteps) ? state.completedSteps : [] };
}

function isComplete(dataDir, state, step) {
  return state.completedSteps.includes(step) && fs.existsSync(path.join(dataDir, OUTPUTS[step]));
}

export function runMigration(dataDir) {
  const statePath = path.join(dataDir, "migration-state.json");
  const state = loadState(dataDir);
  const ranSteps = [];

  for (const step of [1, 2, 3]) {
    if (isComplete(dataDir, state, step)) continue;
    STEPS[step](dataDir);
    state.completedSteps = [...new Set([...state.completedSteps, step])].sort((a, b) => a - b);
    writeJson(statePath, state);
    ranSteps.push(step);
  }

  return { completedSteps: [...state.completedSteps], ranSteps };
}
