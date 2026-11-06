function matches(pattern, value) {
  if (pattern === "*") return true;
  if (pattern.endsWith("*")) return value.startsWith(pattern.slice(0, -1));
  return pattern === value;
}
export function authorize(rules, request) {
  let winner = null;
  for (const rule of rules) {
    if (matches(rule.action, request.action)
      && matches(rule.resource, request.resource)
      && matches(rule.principal ?? "*", request.principal)) winner = rule;
  }
  return winner ? { allowed: winner.effect === "allow", rule: winner.id }
    : { allowed: false, rule: null };
}
