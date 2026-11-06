import test from "node:test";
import assert from "node:assert";
import { authorize } from "../src/policy.js";

test("an exact allow matches", () => {
  const rules = [{ id: "r1", effect: "allow", action: "read", resource: "doc", priority: 1 }];
  assert.deepStrictEqual(authorize(rules, { action: "read", resource: "doc", principal: "u" }),
    { allowed: true, rule: "r1" });
});
