# Specification: proxy auction

## API

`reset()`, `createAuction({ id, reserveCents, endsAt })`,
`bid({ auctionId, bidder, maxCents, now })`, `close({ id, now })`, `auction(id)`.

## Rules

1. **Auction.** Unique id; `reserveCents` is a non-negative integer; `endsAt` is an integer.
   Duplicate id fails with `duplicate_auction: <id>`; invalid values with `invalid_auction`.
2. **Bid validation.** The auction must exist (`auction_not_found: <id>`) and be open
   (`auction_closed`). `bidder` is a non-empty string; `maxCents` is a positive integer.
   A bidder may raise their own maximum, but not lower or repeat it (`bid_too_low`).
   A bid at or below the current price also fails with `bid_too_low`.
3. **Leader and price.** Keep each bidder's highest maximum and its first-bid order.
   The leader is the highest maximum; ties go to the earlier first bid. The price is:
   - `null` when the leader's maximum is below the reserve;
   - otherwise `reserveCents` when there is no other bidder;
   - otherwise `max(reserveCents, min(leaderMax, secondMax + 1))`, where `secondMax` is
     the highest maximum from a different bidder.
4. **Close.** Only at or after `endsAt`; earlier fails with `auction_not_ended`. Closing is
   idempotent and returns `{ winner, priceCents }`; an unsold auction returns
   `{ winner: null, priceCents: null }`.
5. **Lookup.** `auction(id)` returns the auction state including `leader`, `priceCents` and
   `closed`.

## Invariants

- Existing tests in `test/auction.test.js` keep passing.
- A rejected bid never changes the leader, price or bid history.
