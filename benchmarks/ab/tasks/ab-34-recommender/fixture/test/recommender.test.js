import test from "node:test";
import assert from "node:assert";
import { bucket, recordInteraction, recommend, reset } from "../src/recommender.js";
test("records interactions and returns recommendations", () => {
  reset();
  recordInteraction({ userId: "U1", itemId: "A", type: "view" });
  assert.ok(Array.isArray(recommend({ userId: "U1" })));
  assert.strictEqual(typeof bucket({ userId: "U1", experiment: "e1" }), "number");
});
