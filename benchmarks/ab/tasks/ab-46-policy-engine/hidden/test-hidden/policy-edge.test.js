import test from "node:test";
import assert from "node:assert";
import { authorize } from "../src/policy.js";

const request = { action: "read", resource: "doc", principal: "u" };

test("deny wins at equal priority", () => {
  const rules = [
    { id: "allow", effect: "allow", action: "read", resource: "doc", priority: 1 },
    { id: "deny", effect: "deny", action: "read", resource: "doc", priority: 1 },
  ];
  assert.deepStrictEqual(authorize(rules, request), { allowed: false, rule: "deny" });
});

test("higher priority allow beats deny", () => {
  const rules = [
    { id: "deny", effect: "deny", action: "read", resource: "doc", priority: 1 },
    { id: "allow", effect: "allow", action: "read", resource: "doc", priority: 2 },
  ];
  assert.deepStrictEqual(authorize(rules, request), { allowed: true, rule: "allow" });
});

test("prefix and star wildcards match", () => {
  const rules = [
    { id: "star", effect: "allow", action: "*", resource: "*", priority: 1 },
    { id: "prefix", effect: "deny", action: "read*", resource: "doc*", priority: 2 },
  ];
  assert.deepStrictEqual(authorize(rules, request), { allowed: false, rule: "prefix" });
});

test("principal defaults to any", () => {
  const rules = [{ id: "any", effect: "allow", action: "read", resource: "doc", priority: 1 }];
  assert.deepStrictEqual(authorize(rules, { action: "read", resource: "doc", principal: "other" }),
    { allowed: true, rule: "any" });
});

test("no match defaults to deny", () => {
  assert.deepStrictEqual(authorize([], request), { allowed: false, rule: null });
});

test("same effect ties use the smaller id", () => {
  const rules = [
    { id: "z", effect: "allow", action: "read", resource: "doc", priority: 1 },
    { id: "a", effect: "allow", action: "read", resource: "doc", priority: 1 },
  ];
  assert.deepStrictEqual(authorize(rules, request), { allowed: true, rule: "a" });
});

test("invalid rules and duplicate ids fail", () => {
  assert.throws(() => authorize([{ id: "bad", effect: "maybe", action: "*", resource: "*", priority: 1 }], request),
    { message: "invalid_rule: bad" });
  assert.throws(() => authorize([
    { id: "dup", effect: "allow", action: "*", resource: "*", priority: 1 },
    { id: "dup", effect: "deny", action: "*", resource: "*", priority: 1 },
  ], request), { message: "duplicate_rule: dup" });
});
