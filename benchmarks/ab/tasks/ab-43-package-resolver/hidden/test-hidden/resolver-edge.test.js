import test from "node:test";
import assert from "node:assert";
import { resolve } from "../src/resolver.js";

function lib(versions) { return versions.map((version) => ({ version, dependencies: {} })); }

test("selects the highest version for exact, caret, tilde and star", () => {
  const registry = {
    app: [{ version: "1.0.0", dependencies: { lib: "^1.0.0", tilde: "~1.0.0", exact: "1.0.0", any: "*" } }],
    lib: lib(["1.0.0", "1.2.0", "2.0.0"]),
    tilde: lib(["1.0.0", "1.0.5", "1.1.0"]),
    exact: lib(["1.0.0", "1.0.1"]),
    any: lib(["1.0.0", "2.0.0"]),
  };
  const { selected } = resolve({ root: "app", registry });
  assert.strictEqual(selected.lib, "1.2.0");
  assert.strictEqual(selected.tilde, "1.0.5");
  assert.strictEqual(selected.exact, "1.0.0");
  assert.strictEqual(selected.any, "2.0.0");
});

test("resolves transitive dependencies and order is dependency-first", () => {
  const registry = {
    app: [{ version: "1.0.0", dependencies: { a: "^1.0.0" } }],
    a: [{ version: "1.0.0", dependencies: { b: "*" } }],
    b: lib(["1.0.0", "2.0.0"]),
  };
  const result = resolve({ root: "app", registry });
  assert.strictEqual(result.selected.b, "2.0.0");
  assert.deepStrictEqual(result.order, ["b", "a", "app"]);
});

test("conflicting constraints fail", () => {
  const registry = {
    app: [{ version: "1.0.0", dependencies: { a: "^1.0.0", b: "^1.0.0" } }],
    a: lib(["1.0.0", "2.0.0"]),
    b: [{ version: "1.0.0", dependencies: { a: "^2.0.0" } }],
  };
  assert.throws(() => resolve({ root: "app", registry }),
    { message: "version_conflict: a" });
});

test("missing packages fail", () => {
  assert.throws(() => resolve({ root: "nope", registry: {} }),
    { message: "package_not_found: nope" });
  const registry = { app: [{ version: "1.0.0", dependencies: { missing: "*" } }] };
  assert.throws(() => resolve({ root: "app", registry }),
    { message: "package_not_found: missing" });
});

test("cycles terminate with one version per package", () => {
  const registry = {
    a: [{ version: "1.0.0", dependencies: { b: "*" } }],
    b: [{ version: "1.0.0", dependencies: { a: "*" } }],
  };
  const result = resolve({ root: "a", registry });
  assert.deepStrictEqual(result.selected, { a: "1.0.0", b: "1.0.0" });
  assert.deepStrictEqual(result.order, ["b", "a"]);
});

test("invalid versions fail", () => {
  const registry = { app: [{ version: "one", dependencies: {} }] };
  assert.throws(() => resolve({ root: "app", registry }), { message: "invalid_version: one" });
});
