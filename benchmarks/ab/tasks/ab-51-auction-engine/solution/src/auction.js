function fail(code) { throw new Error(code); }
const auctions = new Map();
export function reset() { auctions.clear(); }
function get(id) { const current = auctions.get(id); if (!current) fail(`auction_not_found: ${id}`); return current; }
function standings(current) {
  const best = new Map();
  for (const offer of current.bids) {
    const prior = best.get(offer.bidder);
    if (!prior || offer.maxCents > prior.maxCents
      || (offer.maxCents === prior.maxCents && offer.seq < prior.seq)) best.set(offer.bidder, offer);
  }
  const sorted = [...best.values()].sort((a, b) => b.maxCents - a.maxCents || a.seq - b.seq);
  const top = sorted[0] ?? null;
  const second = top ? sorted.find((offer) => offer.bidder !== top.bidder) ?? null : null;
  if (!top || top.maxCents < current.reserveCents) return { top, second, leader: null, priceCents: null };
  const priceCents = second
    ? Math.max(current.reserveCents, Math.min(top.maxCents, second.maxCents + 1))
    : current.reserveCents;
  return { top, second, leader: top.bidder, priceCents };
}
export function createAuction({ id, reserveCents, endsAt }) {
  if (auctions.has(id)) fail(`duplicate_auction: ${id}`);
  if (!Number.isInteger(reserveCents) || reserveCents < 0 || !Number.isInteger(endsAt)) {
    fail("invalid_auction");
  }
  const current = { id, reserveCents, endsAt, bids: [], closed: false, leader: null, priceCents: null };
  auctions.set(id, current);
  return current;
}
export function bid({ auctionId, bidder, maxCents, now }) {
  const current = get(auctionId);
  if (current.closed || now >= current.endsAt) fail("auction_closed");
  if (typeof bidder !== "string" || !bidder || !Number.isInteger(maxCents) || maxCents <= 0) {
    fail("invalid_bid");
  }
  const prior = current.bids.find((offer) => offer.bidder === bidder);
  if (prior && maxCents <= prior.maxCents) fail("bid_too_low");
  if (current.leader && maxCents <= current.priceCents) fail("bid_too_low");
  current.bids.push({ bidder, maxCents, seq: current.bids.length });
  const result = standings(current);
  current.leader = result.leader; current.priceCents = result.priceCents;
  return { leader: result.leader, priceCents: result.priceCents };
}
export function close({ id, now }) {
  const current = get(id);
  if (now < current.endsAt) fail("auction_not_ended");
  if (current.closed) return { winner: current.leader, priceCents: current.priceCents };
  const result = standings(current);
  current.leader = result.leader; current.priceCents = result.priceCents; current.closed = true;
  return { winner: current.leader, priceCents: current.priceCents };
}
export function auction(id) {
  const current = get(id);
  return { id: current.id, reserveCents: current.reserveCents, endsAt: current.endsAt,
    closed: current.closed, leader: current.leader, priceCents: current.priceCents };
}
