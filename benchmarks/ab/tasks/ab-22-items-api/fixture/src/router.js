export function matchRoute(routes, method, pathname) {
  const actual = pathname.split("/").filter(Boolean);
  for (const route of routes) {
    if (route.method !== method) continue;
    const expected = route.path.split("/").filter(Boolean);
    if (expected.length !== actual.length) continue;
    const params = {};
    let matched = true;
    for (let i = 0; i < expected.length; i += 1) {
      if (expected[i].startsWith(":")) params[expected[i].slice(1)] = decodeURIComponent(actual[i]);
      else if (expected[i] !== actual[i]) { matched = false; break; }
    }
    if (matched) return { route, params };
  }
  return null;
}
