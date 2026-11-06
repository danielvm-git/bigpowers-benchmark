const users = new Map();
const tracks = new Map();
const playlists = new Map();
const purchases = new Map();
const entitlements = new Set();
const idempotency = new Map();
let nextPurchase = 1;

export function reset() {
  users.clear(); tracks.clear(); playlists.clear(); purchases.clear(); entitlements.clear(); idempotency.clear(); nextPurchase = 1;
}

function fail(code) { throw new Error(code); }
function requireUser(id) { const u = users.get(id); if (!u) fail(`user_not_found: ${id}`); return u; }
function requireTrack(id) { const t = tracks.get(id); if (!t) fail(`track_not_found: ${id}`); return t; }
function requirePlaylist(id) { const p = playlists.get(id); if (!p) fail(`playlist_not_found: ${id}`); return p; }
function requireOwner(playlist, userId) { if (playlist.userId !== userId) fail("not_playlist_owner"); }

export function createUser({ id, name }) {
  if (typeof id !== "string" || !id) fail("invalid_user_id");
  if (users.has(id)) fail(`duplicate_user: ${id}`);
  const user = { id, name }; users.set(id, user); return { ...user };
}
export function createTrack({ id, title, priceCents }) {
  if (typeof id !== "string" || !id) fail("invalid_track_id");
  if (tracks.has(id)) fail(`duplicate_track: ${id}`);
  if (!Number.isInteger(priceCents) || priceCents < 0) fail("invalid_price");
  const track = { id, title, priceCents }; tracks.set(id, track); return { ...track };
}
export function createPlaylist({ id, userId, name }) {
  requireUser(userId);
  if (typeof id !== "string" || !id) fail("invalid_playlist_id");
  if (playlists.has(id)) fail(`duplicate_playlist: ${id}`);
  const playlist = { id, userId, name, tracks: [] }; playlists.set(id, playlist);
  return { id, userId, name, tracks: [] };
}
export function addTrackToPlaylist({ playlistId, trackId, userId }) {
  const playlist = requirePlaylist(playlistId); requireOwner(playlist, userId); requireTrack(trackId);
  if (playlist.tracks.includes(trackId)) fail("track_already_in_playlist");
  playlist.tracks.push(trackId);
  return { playlistId, tracks: [...playlist.tracks] };
}
export function removeTrackFromPlaylist({ playlistId, trackId, userId }) {
  const playlist = requirePlaylist(playlistId); requireOwner(playlist, userId);
  if (!playlist.tracks.includes(trackId)) fail("track_not_in_playlist");
  playlist.tracks = playlist.tracks.filter((id) => id !== trackId);
  return { playlistId, tracks: [...playlist.tracks] };
}
export function playlistTracks({ playlistId, userId }) {
  const playlist = requirePlaylist(playlistId); requireOwner(playlist, userId);
  return [...playlist.tracks];
}
export function purchase({ userId, trackId, idempotencyKey }) {
  requireUser(userId); const track = requireTrack(trackId);
  if (typeof idempotencyKey !== "string" || !idempotencyKey.trim()) fail("invalid_idempotency_key");
  if (idempotency.has(idempotencyKey)) return { ...idempotency.get(idempotencyKey) };
  if (entitlements.has(`${userId}:${trackId}`)) fail("already_owned");
  const record = { id: `PU-${nextPurchase++}`, userId, trackId, amountCents: track.priceCents, status: "paid" };
  purchases.set(record.id, record); entitlements.add(`${userId}:${trackId}`); idempotency.set(idempotencyKey, record);
  return { ...record };
}
export function refund({ purchaseId, userId }) {
  const record = purchases.get(purchaseId);
  if (!record) fail(`purchase_not_found: ${purchaseId}`);
  if (record.userId !== userId) fail("not_purchaser");
  if (record.status === "refunded") return { ...record };
  record.status = "refunded";
  entitlements.delete(`${record.userId}:${record.trackId}`);
  return { ...record };
}
export function hasEntitlement({ userId, trackId }) { return entitlements.has(`${userId}:${trackId}`); }
