import test from "node:test";
import assert from "node:assert";
import { feed } from "../src/feed.js";

test("returns public posts newest first", () => {
  const result = feed({
    posts: [
      { id: "a", author: "u", visibility: "public", createdAt: 1, seq: 1 },
      { id: "b", author: "u", visibility: "public", createdAt: 2, seq: 1 },
    ], viewer: { id: "v", following: [] }, limit: 10,
  });
  assert.deepStrictEqual(result.items.map((post) => post.id), ["b", "a"]);
});
