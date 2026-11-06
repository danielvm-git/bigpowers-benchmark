export function resolve({ root, registry }) {
  const selected = { [root]: registry[root][0].version };
  const order = [root];
  for (const dep of Object.keys(registry[root][0].dependencies ?? {})) {
    selected[dep] = registry[dep][0].version;
    order.unshift(dep);
  }
  return { selected, order };
}
