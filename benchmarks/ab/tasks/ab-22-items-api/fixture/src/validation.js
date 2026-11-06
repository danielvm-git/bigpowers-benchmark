export function validateItem(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) return "body must be an object";
  if (typeof input.name !== "string" || !input.name.trim()) return "name must be a non-empty string";
  if (!Number.isInteger(input.priceCents) || input.priceCents < 0) return "priceCents must be a non-negative integer";
  if (!Number.isInteger(input.quantity) || input.quantity < 0) return "quantity must be a non-negative integer";
  return null;
}
