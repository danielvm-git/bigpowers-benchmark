import test from "node:test";
import assert from "node:assert";
import { createPost, createUser, feed, follow, reset } from "../src/social.js";

test("creates users, follows and returns posts", () => {
  reset();
  createUser({ id: "U1" });
  createUser({ id: "U2" });
  follow({ followerId: "U1", followeeId: "U2" });
  createPost({ id: "P1", userId: "U2", text: "hello" });
  assert.strictEqual(feed({ userId: "U1" }).length, 1);
});
