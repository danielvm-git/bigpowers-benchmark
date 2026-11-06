function fail(code) { throw new Error(code); }
function visible(post, viewer) {
  if (post.visibility === "public" || post.author === viewer.id) return true;
  return post.visibility === "followers" && viewer.following.includes(post.author);
}
function compareDesc(a, b) { return b.createdAt - a.createdAt || b.seq - a.seq; }
function parseCursor(cursor) {
  const match = /^(-?\d+):(-?\d+)$/.exec(cursor ?? "");
  if (!match) fail("invalid_cursor");
  return { createdAt: Number(match[1]), seq: Number(match[2]) };
}
export function feed({ posts, viewer, limit, cursor }) {
  if (!Number.isInteger(limit) || limit <= 0) fail("invalid_limit");
  const after = cursor === undefined ? null : parseCursor(cursor);
  const visiblePosts = posts.filter((post) => visible(post, viewer))
    .filter((post) => !after || post.createdAt < after.createdAt
      || (post.createdAt === after.createdAt && post.seq < after.seq))
    .sort(compareDesc);
  const items = visiblePosts.slice(0, limit);
  const nextCursor = visiblePosts.length > limit
    ? `${items[items.length - 1].createdAt}:${items[items.length - 1].seq}` : null;
  return { items, nextCursor };
}
