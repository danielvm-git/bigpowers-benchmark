import test from "node:test";
import assert from "node:assert";
import { feed } from "../src/feed.js";

const viewer = { id: "v", following: ["friend"] };
function post(id, author, visibility, createdAt, seq) {
  return { id, author, visibility, createdAt, seq };
}
const posts = [
  post("old", "u", "public", 1, 1),
  post("tie1", "u", "public", 2, 1),
  post("tie2", "u", "public", 2, 2),
  post("friend", "friend", "followers", 3, 1),
  post("private", "u", "private", 4, 1),
  post("own", "v", "private", 5, 1),
];

test("visibility includes public, followed and own posts", () => {
  const ids = feed({ posts, viewer, limit: 10 }).items.map((item) => item.id);
  assert.deepStrictEqual(ids, ["own", "friend", "tie2", "tie1", "old"]);
});

test("private posts are hidden from other viewers", () => {
  const ids = feed({ posts, viewer: { id: "x", following: ["friend"] }, limit: 10 })
    .items.map((item) => item.id);
  assert.ok(!ids.includes("private"));
  assert.ok(!ids.includes("own"));
});

test("ordering uses createdAt then descending seq", () => {
  const ids = feed({ posts, viewer, limit: 3 }).items.map((item) => item.id);
  assert.deepStrictEqual(ids, ["own", "friend", "tie2"]);
});

test("pagination does not duplicate or skip", () => {
  const first = feed({ posts, viewer, limit: 2 });
  const second = feed({ posts, viewer, limit: 2, cursor: first.nextCursor });
  const third = feed({ posts, viewer, limit: 2, cursor: second.nextCursor });
  assert.deepStrictEqual([...first.items, ...second.items, ...third.items].map((item) => item.id),
    ["own", "friend", "tie2", "tie1", "old"]);
  assert.strictEqual(third.nextCursor, null);
});

test("cursor on a tie boundary skips the rest of the tie", () => {
  const first = feed({ posts, viewer, limit: 3 });
  assert.strictEqual(first.nextCursor, "2:2");
  const second = feed({ posts, viewer, limit: 2, cursor: first.nextCursor });
  assert.deepStrictEqual(second.items.map((item) => item.id), ["tie1", "old"]);
});

test("invalid limits and cursors fail", () => {
  assert.throws(() => feed({ posts, viewer, limit: 0 }), { message: "invalid_limit" });
  assert.throws(() => feed({ posts, viewer, limit: 1, cursor: "bad" }),
    { message: "invalid_cursor" });
});

test("empty feeds return a null cursor", () => {
  assert.deepStrictEqual(feed({ posts: [], viewer, limit: 2 }),
    { items: [], nextCursor: null });
});
