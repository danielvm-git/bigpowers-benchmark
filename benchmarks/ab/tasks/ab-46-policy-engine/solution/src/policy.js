function fail(code) { throw new Error(code); }
function matches(pattern, value) {
  if (pattern === "*") return true;
  if (pattern.endsWith("*")) return value.startsWith(pattern.slice(0, -1));
  return pattern === value;
}
function validRule(rule) {
  return rule && typeof rule.id === "string" && (rule.effect === "allow" || rule.effect === "deny")
    && typeof rule.action === "string" && typeof rule.resource === "string"
    && (rule.principal === undefined || typeof rule.principal === "string")
    && Number.isInteger(rule.priority);
}
export function authorize(rules, request) {
  if (!request || typeof request.action !== "string" || typeof request.resource !== "string"
    || typeof request.principal !== "string") fail("invalid_request");
  const seen = new Set();
  for (const rule of rules) {
    if (!validRule(rule)) fail(`invalid_rule: ${rule?.id ?? "unknown"}`);
    if (seen.has(rule.id)) fail(`duplicate_rule: ${rule.id}`);
    seen.add(rule.id);
  }
  const matched = rules.filter((rule) => matches(rule.action, request.action)
    && matches(rule.resource, request.resource)
    && matches(rule.principal ?? "*", request.principal));
  if (!matched.length) return { allowed: false, rule: null };
  matched.sort((a, b) => b.priority - a.priority
    || (a.effect === b.effect ? 0 : a.effect === "deny" ? -1 : 1)
    || a.id.localeCompare(b.id));
  const winner = matched[0];
  return { allowed: winner.effect === "allow", rule: winner.id };
}
