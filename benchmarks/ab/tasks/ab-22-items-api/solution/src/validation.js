const EDITABLE = ["name", "priceCents", "quantity"];

function has(input, key) {
  return Object.prototype.hasOwnProperty.call(input, key);
}

export function hasUpdateFields(input) {
  return EDITABLE.some((key) => has(input, key));
}

export function validateItem(input, { partial = false } = {}) {
  if (!input || typeof input !== "object" || Array.isArray(input)) return "body must be an object";
  if (!partial || has(input, "name")) {
    if (typeof input.name !== "string" || !input.name.trim()) return "name must be a non-empty string";
  }
  if (!partial || has(input, "priceCents")) {
    if (!Number.isInteger(input.priceCents) || input.priceCents < 0) return "priceCents must be a non-negative integer";
  }
  if (!partial || has(input, "quantity")) {
    if (!Number.isInteger(input.quantity) || input.quantity < 0) return "quantity must be a non-negative integer";
  }
  return null;
}
