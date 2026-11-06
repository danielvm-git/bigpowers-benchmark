import test from "node:test";
import assert from "node:assert";
import { resolve } from "../src/resolver.js";
test("resolves a root and its dependency", () => {
  const registry = {
    app: [{ version: "1.0.0", dependencies: { lib: "^1.0.0" } }],
    lib: [{ version: "1.0.0", dependencies: {} }, { version: "1.2.0", dependencies: {} }],
  };
  const result = resolve({ root: "app", registry });
  assert.strictEqual(result.selected.app, "1.0.0");
  assert.ok("lib" in result.selected);
  assert.ok(result.order.includes("lib"));
});
