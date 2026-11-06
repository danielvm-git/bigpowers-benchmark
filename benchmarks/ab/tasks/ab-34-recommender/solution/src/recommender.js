const userItems = new Map();
const itemUsers = new Map();
const itemTotals = new Map();
const TYPE_WEIGHTS = { view: 1, like: 3, purchase: 5 };

export function reset() {
  userItems.clear(); itemUsers.clear(); itemTotals.clear();
}
function fail(code) { throw new Error(code); }

export function recordInteraction({ userId, itemId, type = "view", weight }) {
  if (typeof userId !== "string" || !userId) fail("invalid_user_id");
  if (typeof itemId !== "string" || !itemId) fail("invalid_item_id");
  if (!(type in TYPE_WEIGHTS)) fail("invalid_interaction_type");
  const value = weight === undefined ? TYPE_WEIGHTS[type] : weight;
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) fail("invalid_weight");

  const items = userItems.get(userId) ?? new Map();
  items.set(itemId, (items.get(itemId) ?? 0) + value);
  userItems.set(userId, items);
  const users = itemUsers.get(itemId) ?? new Map();
  users.set(userId, (users.get(userId) ?? 0) + value);
  itemUsers.set(itemId, users);
  itemTotals.set(itemId, (itemTotals.get(itemId) ?? 0) + value);
  return { userId, itemId, type, weight: value };
}

export function recommend({ userId, limit = 5 }) {
  if (typeof userId !== "string" || !userId) fail("invalid_user_id");
  if (!Number.isInteger(limit) || limit <= 0) fail("invalid_limit");
  const seen = userItems.get(userId) ?? new Map();
  const scores = new Map();

  if (seen.size === 0) {
    return [...itemTotals.entries()]
      .sort(([a, wa], [b, wb]) => wb - wa || a.localeCompare(b))
      .slice(0, limit).map(([item]) => item);
  }

  for (const [seedItem, seedWeight] of seen) {
    for (const [otherUser, otherSeedWeight] of itemUsers.get(seedItem) ?? []) {
      if (otherUser === userId) continue;
      for (const [candidate, candidateWeight] of userItems.get(otherUser) ?? []) {
        if (seen.has(candidate)) continue;
        scores.set(candidate, (scores.get(candidate) ?? 0) + seedWeight * candidateWeight);
      }
    }
  }
  return [...scores.entries()]
    .sort(([a, sa], [b, sb]) => sb - sa || a.localeCompare(b))
    .slice(0, limit).map(([item]) => item);
}

function hash(value) {
  let h = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    h ^= value.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function bucket({ userId, experiment }) {
  if (typeof userId !== "string" || !userId) fail("invalid_user_id");
  if (typeof experiment !== "string" || !experiment) fail("invalid_experiment");
  return hash(`${userId}:${experiment}`) % 100;
}
