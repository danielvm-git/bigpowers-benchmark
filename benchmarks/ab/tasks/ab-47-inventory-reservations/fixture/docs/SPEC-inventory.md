# Specification: inventory reservations

## API

`reset()`, `addItem({ sku, stock })`, `reserve({ sku, qty, now, ttl })`,
`confirm({ id, now })`, `cancel({ id, now })`, `sweep(now)`,
`available(sku, now)`, `reservation(id)`.

## Rules

1. **Items.** `stock` is a non-negative integer; a duplicate sku fails with
   `duplicate_item: <sku>`. Unknown sku fails with `item_not_found: <sku>`.
2. **Reserve.** `qty` and `ttl` are positive integers. A pending reservation holds `qty`
   units until `expiresAt = now + ttl`. Reserve fails with `insufficient_stock: <sku>`
   when `available < qty`. New ids are `r1`, `r2`, ... in creation order.
3. **Availability.** `stock - sum(qty of pending reservations with now < expiresAt)`.
   A reservation expires exactly at `now == expiresAt`.
4. **Confirm.** Only a pending, unexpired reservation can be confirmed; it reduces stock by
   `qty` and becomes `confirmed`. Expired fails with `reservation_expired`; any other
   status fails with `reservation_not_pending`.
5. **Cancel.** Only a pending, unexpired reservation can be cancelled; it becomes
   `cancelled` and releases its hold. Errors match confirm.
6. **Sweep.** Marks every expired pending reservation `expired` and returns the count.
   Sweeping twice returns 0 the second time.
7. **Unknown reservation.** `reservation_not_found: <id>`.

## Invariants

- Existing tests in `test/inventory.test.js` keep passing.
- A failed confirm or cancel never changes stock or status.
