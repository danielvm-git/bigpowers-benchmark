import test from "node:test";
import assert from "node:assert";
import {
  acceptFollow, canView, createPost, createUser, feed, follow, rejectFollow, reset,
} from "../src/social.js";

function users() {
  reset();
  createUser({ id: "U1" });
  createUser({ id: "U2" });
  createUser({ id: "U3", private: true });
}

test("public posts are visible to everyone", () => {
  users();
  const post = createPost({ id: "P1", userId: "U2", text: "hello" });
  assert.strictEqual(canView({ viewerId: "U1", postId: post.id }), true);
  assert.deepStrictEqual(feed({ userId: "U1" }).map((p) => p.id), ["P1"]);
});

test("followers-only posts need an accepted follow", () => {
  users();
  const post = createPost({ id: "P1", userId: "U2", text: "secret", visibility: "followers" });
  assert.strictEqual(canView({ viewerId: "U1", postId: "P1" }), false);
  follow({ followerId: "U1", followeeId: "U2" });
  assert.strictEqual(canView({ viewerId: "U1", postId: "P1" }), true);
  assert.deepStrictEqual(feed({ userId: "U1" }).map((p) => p.id), ["P1"]);
});

test("a pending follow never grants visibility", () => {
  users();
  const post = createPost({ id: "P1", userId: "U3", text: "private", visibility: "public" });
  assert.deepStrictEqual(follow({ followerId: "U1", followeeId: "U3" }), { status: "pending" });
  assert.strictEqual(canView({ viewerId: "U1", postId: "P1" }), false);
  assert.strictEqual(feed({ userId: "U1" }).length, 0);

  acceptFollow({ followerId: "U1", followeeId: "U3" });
  assert.strictEqual(canView({ viewerId: "U1", postId: "P1" }), true);
});

test("rejecting a follow leaves no visibility", () => {
  users();
  createPost({ id: "P1", userId: "U3", text: "private" });
  follow({ followerId: "U1", followeeId: "U3" });
  rejectFollow({ followerId: "U1", followeeId: "U3" });
  assert.strictEqual(canView({ viewerId: "U1", postId: "P1" }), false);
});

test("a private account hides even public posts from non-followers", () => {
  users();
  createPost({ id: "P1", userId: "U3", text: "private account", visibility: "public" });
  assert.strictEqual(canView({ viewerId: "U2", postId: "P1" }), false);
  assert.strictEqual(canView({ viewerId: "U3", postId: "P1" }), true);
  follow({ followerId: "U2", followeeId: "U3" });
  acceptFollow({ followerId: "U2", followeeId: "U3" });
  assert.strictEqual(canView({ viewerId: "U2", postId: "P1" }), true);
});

test("the feed is newest-first and cursor pagination never repeats", () => {
  users();
  for (let i = 1; i <= 5; i += 1) {
    createPost({ id: `P${i}`, userId: "U1", text: `post ${i}` });
  }
  assert.deepStrictEqual(feed({ userId: "U1", limit: 2 }).map((p) => p.id), ["P5", "P4"]);
  assert.deepStrictEqual(feed({ userId: "U1", limit: 2, cursor: 4 }).map((p) => p.id), ["P3", "P2"]);
  assert.deepStrictEqual(feed({ userId: "U1", limit: 2, cursor: 2 }).map((p) => p.id), ["P1"]);
  assert.deepStrictEqual(feed({ userId: "U1", limit: 2, cursor: 1 }), []);
});

test("follow validation and duplicates", () => {
  users();
  assert.throws(() => follow({ followerId: "U1", followeeId: "U1" }), { message: "self_follow" });
  assert.throws(() => follow({ followerId: "U1", followeeId: "X" }),
    { message: "user_not_found: X" });
  assert.deepStrictEqual(follow({ followerId: "U1", followeeId: "U2" }), { status: "accepted" });
  assert.deepStrictEqual(follow({ followerId: "U1", followeeId: "U2" }), { status: "accepted" });
  assert.throws(() => acceptFollow({ followerId: "U1", followeeId: "U2" }),
    { message: "follow_not_found" });
});

test("post validation and unknown lookups", () => {
  users();
  assert.throws(() => createPost({ id: "P1", userId: "X", text: "x" }),
    { message: "user_not_found: X" });
  assert.throws(() => createPost({ id: "P1", userId: "U1", text: "x", visibility: "friends" }),
    { message: "invalid_visibility" });
  createPost({ id: "P1", userId: "U1", text: "x" });
  assert.throws(() => createPost({ id: "P1", userId: "U1", text: "again" }),
    { message: "duplicate_post: P1" });
  assert.throws(() => canView({ viewerId: "X", postId: "P1" }),
    { message: "user_not_found: X" });
  assert.throws(() => canView({ viewerId: "U1", postId: "X" }),
    { message: "post_not_found: X" });
});

test("feed limit validation", () => {
  users();
  for (const limit of [0, -1, 1.5]) {
    assert.throws(() => feed({ userId: "U1", limit }), { message: "invalid_limit" });
  }
});
