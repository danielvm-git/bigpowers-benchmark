import test from "node:test";
import assert from "node:assert";
import { reset, createAuction, bid, close, auction } from "../src/auction.js";

function make() { reset(); createAuction({ id: "a1", reserveCents: 100, endsAt: 10 }); return "a1"; }

test("a single bid at reserve sets the reserve price", () => {
  const id = make();
  assert.deepStrictEqual(bid({ auctionId: id, bidder: "u1", maxCents: 100, now: 0 }),
    { leader: "u1", priceCents: 100 });
});

test("two bidders pay second max plus one", () => {
  const id = make();
  bid({ auctionId: id, bidder: "u1", maxCents: 200, now: 0 });
  assert.deepStrictEqual(bid({ auctionId: id, bidder: "u2", maxCents: 150, now: 1 }),
    { leader: "u1", priceCents: 151 });
});

test("outbidding raises the proxy price", () => {
  const id = make();
  bid({ auctionId: id, bidder: "u1", maxCents: 100, now: 0 });
  assert.deepStrictEqual(bid({ auctionId: id, bidder: "u2", maxCents: 300, now: 1 }),
    { leader: "u2", priceCents: 101 });
});

test("ties go to the earlier first bid", () => {
  const id = make();
  bid({ auctionId: id, bidder: "u1", maxCents: 200, now: 0 });
  bid({ auctionId: id, bidder: "u2", maxCents: 200, now: 1 });
  assert.strictEqual(auction(id).leader, "u1");
  assert.strictEqual(auction(id).priceCents, 200);
});

test("bids below reserve leave the auction unsold", () => {
  const id = make();
  assert.deepStrictEqual(bid({ auctionId: id, bidder: "u1", maxCents: 99, now: 0 }),
    { leader: null, priceCents: null });
  assert.deepStrictEqual(close({ id, now: 10 }), { winner: null, priceCents: null });
});

test("bids close at endsAt and close is idempotent", () => {
  const id = make();
  bid({ auctionId: id, bidder: "u1", maxCents: 200, now: 9 });
  assert.throws(() => bid({ auctionId: id, bidder: "u2", maxCents: 300, now: 10 }),
    { message: "auction_closed" });
  assert.deepStrictEqual(close({ id, now: 10 }), { winner: "u1", priceCents: 100 });
  assert.deepStrictEqual(close({ id, now: 11 }), { winner: "u1", priceCents: 100 });
});

test("too-low bids and invalid values fail", () => {
  const id = make();
  bid({ auctionId: id, bidder: "u1", maxCents: 200, now: 0 });
  assert.throws(() => bid({ auctionId: id, bidder: "u1", maxCents: 200, now: 1 }),
    { message: "bid_too_low" });
  assert.throws(() => bid({ auctionId: id, bidder: "u2", maxCents: 100, now: 1 }),
    { message: "bid_too_low" });
  assert.throws(() => bid({ auctionId: id, bidder: "", maxCents: 300, now: 1 }),
    { message: "invalid_bid" });
});

test("a bidder can raise their own max without losing the lead", () => {
  const id = make();
  bid({ auctionId: id, bidder: "u1", maxCents: 200, now: 0 });
  bid({ auctionId: id, bidder: "u2", maxCents: 150, now: 1 });
  assert.deepStrictEqual(bid({ auctionId: id, bidder: "u1", maxCents: 250, now: 2 }),
    { leader: "u1", priceCents: 151 });
});
