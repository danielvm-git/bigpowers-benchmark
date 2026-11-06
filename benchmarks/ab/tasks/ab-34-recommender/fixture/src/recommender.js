const interactions = [];
export function reset() { interactions.length = 0; }
export function recordInteraction({ userId, itemId, type = "view", weight }) {
  interactions.push({ userId, itemId, type, weight });
  return { userId, itemId, type, weight };
}
export function recommend({ userId, limit = 5 }) {
  return [...new Set(interactions.map((i) => i.itemId))].slice(0, limit);
}
export function bucket({ userId, experiment }) { return 0; }
