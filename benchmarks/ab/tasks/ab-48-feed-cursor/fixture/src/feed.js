export function feed({ posts, viewer, limit }) {
  const visible = posts.filter((post) => post.visibility === "public")
    .sort((a, b) => b.createdAt - a.createdAt);
  const items = visible.slice(0, limit);
  return { items, nextCursor: null };
}
