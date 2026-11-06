const users = new Map();
const posts = [];
let nextSeq = 1;

export function reset() {
  users.clear();
  posts.length = 0;
  nextSeq = 1;
}

export function createUser({ id, private: isPrivate = false }) {
  const user = { id, private: Boolean(isPrivate) };
  users.set(id, user);
  return { ...user };
}

export function follow({ followerId, followeeId }) {
  return { status: "accepted" };
}

export function createPost({ id, userId, text, visibility = "public" }) {
  const post = { id, userId, text, visibility, seq: nextSeq++ };
  posts.push(post);
  return { ...post };
}

export function feed({ userId, limit = 10 }) {
  return posts.slice(0, limit).map((post) => ({ ...post }));
}

export function canView() {
  return true;
}
