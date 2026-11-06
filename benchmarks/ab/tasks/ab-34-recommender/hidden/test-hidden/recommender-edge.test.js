import test from "node:test";
import assert from "node:assert";
import { bucket, recordInteraction, recommend, reset } from "../src/recommender.js";

test("co-occurrence recommends items seen by similar users", () => {
  reset();
  recordInteraction({ userId: "U1", itemId: "A" });
  recordInteraction({ userId: "U2", itemId: "A" });
  recordInteraction({ userId: "U2", itemId: "B" });
  recordInteraction({ userId: "U3", itemId: "C" });
  assert.deepStrictEqual(recommend({ userId: "U1" }), ["B"]);
});

test("already-touched items are never recommended", () => {
  reset();
  recordInteraction({ userId: "U1", itemId: "A" });
  recordInteraction({ userId: "U2", itemId: "A" });
  recordInteraction({ userId: "U2", itemId: "B" });
  recordInteraction({ userId: "U1", itemId: "B" });
  assert.deepStrictEqual(recommend({ userId: "U1" }), []);
});

test("weights and interaction types change the ranking", () => {
  reset();
  recordInteraction({ userId: "U1", itemId: "A", type: "purchase" });
  recordInteraction({ userId: "U2", itemId: "A", type: "purchase" });
  recordInteraction({ userId: "U2", itemId: "B", type: "view" });
  recordInteraction({ userId: "U2", itemId: "C", type: "purchase" });
  assert.deepStrictEqual(recommend({ userId: "U1" }), ["C", "B"]);
});

test("ties break by item id", () => {
  reset();
  recordInteraction({ userId: "U1", itemId: "A" });
  recordInteraction({ userId: "U2", itemId: "A" });
  recordInteraction({ userId: "U2", itemId: "Z" });
  recordInteraction({ userId: "U2", itemId: "B" });
  assert.deepStrictEqual(recommend({ userId: "U1" }), ["B", "Z"]);
});

test("cold start falls back to popular items", () => {
  reset();
  recordInteraction({ userId: "U1", itemId: "A", type: "view" });
  recordInteraction({ userId: "U2", itemId: "A", type: "view" });
  recordInteraction({ userId: "U3", itemId: "B", type: "purchase" });
  assert.deepStrictEqual(recommend({ userId: "NEW" }), ["B", "A"]);
});

test("limit and validation", () => {
  reset();
  recordInteraction({ userId: "U1", itemId: "A" });
  recordInteraction({ userId: "U2", itemId: "A" });
  for (const item of ["B", "C", "D"]) recordInteraction({ userId: "U2", itemId: item });
  assert.strictEqual(recommend({ userId: "U1", limit: 2 }).length, 2);
  for (const limit of [0, -1, 1.5]) {
    assert.throws(() => recommend({ userId: "U1", limit }), { message: "invalid_limit" });
  }
  assert.throws(() => recordInteraction({ userId: "U1", itemId: "A", type: "share" }),
    { message: "invalid_interaction_type" });
  assert.throws(() => recordInteraction({ userId: "U1", itemId: "A", weight: 0 }),
    { message: "invalid_weight" });
});

test("buckets are deterministic and stay in range", () => {
  reset();
  const first = bucket({ userId: "U1", experiment: "checkout" });
  assert.strictEqual(bucket({ userId: "U1", experiment: "checkout" }), first);
  assert.ok(first >= 0 && first < 100);
  const buckets = new Set();
  for (let i = 0; i < 100; i += 1) buckets.add(bucket({ userId: `U${i}`, experiment: "e" }));
  assert.ok(buckets.size > 1);
  assert.notStrictEqual(bucket({ userId: "U1", experiment: "a" }),
    bucket({ userId: "U1", experiment: "b" }));
});
