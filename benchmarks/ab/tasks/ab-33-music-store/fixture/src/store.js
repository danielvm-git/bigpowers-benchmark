const users = new Map();
const tracks = new Map();
const playlists = new Map();
const purchases = new Map();
const entitlements = new Set();
let nextPurchase = 1;

export function reset() {
  users.clear(); tracks.clear(); playlists.clear(); purchases.clear(); entitlements.clear(); nextPurchase = 1;
}
export function createUser({ id, name }) { const user = { id, name }; users.set(id, user); return { ...user }; }
export function createTrack({ id, title, priceCents }) { const track = { id, title, priceCents }; tracks.set(id, track); return { ...track }; }
export function createPlaylist({ id, userId, name }) { const p = { id, userId, name, tracks: [] }; playlists.set(id, p); return { ...p, tracks: [] }; }
export function addTrackToPlaylist({ playlistId, trackId }) { playlists.get(playlistId).tracks.push(trackId); }
export function purchase({ userId, trackId }) { const p = { id: `PU-${nextPurchase++}`, userId, trackId, status: "paid" }; purchases.set(p.id, p); entitlements.add(`${userId}:${trackId}`); return { ...p }; }
export function hasEntitlement({ userId, trackId }) { return entitlements.has(`${userId}:${trackId}`); }
export function refund(purchaseId) { const p = purchases.get(purchaseId); p.status = "refunded"; return { ...p }; }
