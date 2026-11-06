const users = new Map();
const posts = new Map();
let nextSeq = 1;

export function reset() {
  users.clear();
  posts.clear();
  nextSeq = 1;
}

function fail(code) {
  throw new Error(code);
}

function requireUser(id) {
  const user = users.get(id);
  if (!user) fail(`user_not_found: ${id}`);
  return user;
}

function requirePost(id) {
  const post = posts.get(id);
  if (!post) fail(`post_not_found: ${id}`);
  return post;
}

export function createUser({ id, private: isPrivate = false }) {
  if (typeof id !== "string" || !id) fail("invalid_user_id");
  if (users.has(id)) fail(`duplicate_user: ${id}`);
  const user = { id, private: Boolean(isPrivate), followers: new Set(), pending: new Set() };
  users.set(id, user);
  return { id, private: user.private };
}

export function follow({ followerId, followeeId }) {
  const follower = requireUser(followerId);
  const followee = requireUser(followeeId);
  if (followerId === followeeId) fail("self_follow");
  if (followee.followers.has(followerId)) return { status: "accepted" };
  if (followee.pending.has(followerId)) return { status: "pending" };
  if (followee.private) {
    followee.pending.add(followerId);
    return { status: "pending" };
  }
  followee.followers.add(followerId);
  return { status: "accepted" };
}

export function acceptFollow({ followerId, followeeId }) {
  const follower = requireUser(followerId);
  const followee = requireUser(followeeId);
  if (!followee.pending.has(follower.id)) fail("follow_not_found");
  followee.pending.delete(follower.id);
  followee.followers.add(follower.id);
  return { status: "accepted" };
}

export function rejectFollow({ followerId, followeeId }) {
  const follower = requireUser(followerId);
  const followee = requireUser(followeeId);
  if (!followee.pending.has(follower.id)) fail("follow_not_found");
  followee.pending.delete(follower.id);
  return { status: "rejected" };
}

export function createPost({ id, userId, text, visibility = "public" }) {
  const user = requireUser(userId);
  if (typeof id !== "string" || !id) fail("invalid_post_id");
  if (posts.has(id)) fail(`duplicate_post: ${id}`);
  if (typeof text !== "string" || !text.trim()) fail("invalid_text");
  if (visibility !== "public" && visibility !== "followers") fail("invalid_visibility");
  const post = { id, userId: user.id, text, visibility, seq: nextSeq++ };
  posts.set(id, post);
  return { ...post };
}

export function canView({ viewerId, postId }) {
  const viewer = requireUser(viewerId);
  const post = requirePost(postId);
  const author = users.get(post.userId);
  if (viewer.id === author.id) return true;
  if (author.private && !author.followers.has(viewer.id)) return false;
  if (post.visibility === "public") return true;
  return author.followers.has(viewer.id);
}

export function feed({ userId, limit = 10, cursor = null }) {
  const viewer = requireUser(userId);
  if (!Number.isInteger(limit) || limit <= 0) fail("invalid_limit");
  if (cursor !== null && !Number.isInteger(cursor)) fail("invalid_cursor");
  return [...posts.values()]
    .filter((post) => canView({ viewerId: viewer.id, postId: post.id }))
    .filter((post) => cursor === null || post.seq < cursor)
    .sort((a, b) => b.seq - a.seq)
    .slice(0, limit)
    .map((post) => ({ ...post }));
}
