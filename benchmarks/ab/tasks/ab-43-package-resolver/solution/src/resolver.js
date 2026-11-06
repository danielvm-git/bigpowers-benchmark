function fail(code) { throw new Error(code); }
function parseVersion(version) {
  const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
  if (!match) fail(`invalid_version: ${version}`);
  return [Number(match[1]), Number(match[2]), Number(match[3])];
}
function compare(a, b) {
  const va = parseVersion(a); const vb = parseVersion(b);
  for (let i = 0; i < 3; i += 1) if (va[i] !== vb[i]) return va[i] - vb[i];
  return 0;
}
function satisfies(version, range) {
  if (range === "*") return true;
  if (range.startsWith("^")) {
    const base = range.slice(1); if (compare(version, base) < 0) return false;
    return parseVersion(version)[0] === parseVersion(base)[0];
  }
  if (range.startsWith("~")) {
    const base = range.slice(1); if (compare(version, base) < 0) return false;
    const v = parseVersion(version); const b = parseVersion(base);
    return v[0] === b[0] && v[1] === b[1];
  }
  return version === range;
}
export function resolve({ root, registry }) {
  for (const versions of Object.values(registry)) {
    for (const pkg of versions) parseVersion(pkg.version);
  }
  if (!registry[root]) fail(`package_not_found: ${root}`);

  function solve(constraints, selected) {
    for (const [name, version] of selected) {
      const ranges = constraints.get(name) ?? [];
      if (!ranges.every((range) => satisfies(version, range))) fail(`version_conflict: ${name}`);
    }
    const name = [...constraints.keys()].filter((key) => !selected.has(key)).sort()[0];
    if (!name) return { constraints, selected };

    const versions = registry[name];
    if (!versions) fail(`package_not_found: ${name}`);
    const allowed = versions
      .filter((pkg) => constraints.get(name).every((range) => satisfies(pkg.version, range)))
      .sort((a, b) => compare(b.version, a.version));
    if (!allowed.length) fail(`version_conflict: ${name}`);

    let lastError;
    for (const pkg of allowed) {
      const nextSelected = new Map(selected); nextSelected.set(name, pkg.version);
      const nextConstraints = new Map([...constraints].map(([key, ranges]) => [key, [...ranges]]));
      for (const [dep, range] of Object.entries(pkg.dependencies ?? {})) {
        const ranges = nextConstraints.get(dep) ?? [];
        ranges.push(range);
        nextConstraints.set(dep, ranges);
      }
      try { return solve(nextConstraints, nextSelected); } catch (error) { lastError = error; }
    }
    throw lastError ?? new Error(`version_conflict: ${name}`);
  }

  const { selected } = solve(new Map([[root, ["*"]]]), new Map());
  const seen = new Set(); const order = [];
  function visit(name) {
    if (seen.has(name)) return;
    seen.add(name);
    const pkg = registry[name].find((candidate) => candidate.version === selected.get(name));
    for (const dep of Object.keys(pkg.dependencies ?? {})) visit(dep);
    order.push(name);
  }
  visit(root);
  return { selected: Object.fromEntries(selected), order };
}
