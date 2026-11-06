const auctions = new Map();
export function reset() { auctions.clear(); }
export function createAuction({ id, reserveCents, endsAt }) {
  auctions.set(id, { id, reserveCents, endsAt, bids: [], closed: false });
}
export function bid({ auctionId, bidder, maxCents }) {
  const current = auctions.get(auctionId);
  current.bids.push({ bidder, maxCents });
  current.leader = bidder; current.priceCents = maxCents;
  return { leader: bidder, priceCents: maxCents };
}
export function close({ id }) {
  const current = auctions.get(id);
  current.closed = true;
  return { winner: current.leader ?? null, priceCents: current.priceCents ?? null };
}
export function auction(id) { return auctions.get(id); }
