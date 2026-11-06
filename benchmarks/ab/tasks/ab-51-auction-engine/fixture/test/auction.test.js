import test from "node:test";
import assert from "node:assert";
import { reset, createAuction, bid } from "../src/auction.js";

test("a bid becomes the leader", () => {
  reset(); createAuction({ id: "a1", reserveCents: 100, endsAt: 10 });
  const result = bid({ auctionId: "a1", bidder: "u1", maxCents: 200, now: 0 });
  assert.strictEqual(result.leader, "u1");
});
