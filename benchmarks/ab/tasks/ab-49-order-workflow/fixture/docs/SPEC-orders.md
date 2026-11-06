# Specification: order workflow

## API

`reset()`, `createOrder({ id, items, totalCents })`, `pay({ id, paymentId })`,
`ship({ id, tracking })`, `cancel({ id })`, `order(id)`.

## Rules

1. **Create.** `id` is unique; a duplicate fails with `duplicate_order: <id>`. `items` is
   a non-empty array and `totalCents` is a positive integer, otherwise `invalid_order`.
   A new order is `created` with an empty `history`.
2. **Pay.** Only `created` can be paid; it becomes `paid` and records `paymentId`.
   Paying again with the same `paymentId` is idempotent and returns the order unchanged.
   A different `paymentId` fails with `payment_conflict`.
3. **Ship.** Only `paid` can ship; it becomes `shipped` and records `tracking`.
   Shipping an already shipped order is idempotent when the tracking matches.
4. **Cancel.** `created` and `paid` can be cancelled; `paid` cancellation records a refund.
   A `shipped` order cannot be cancelled (`invalid_transition`).
5. **History.** Every effective transition appends `{ action }` in order.
6. **Invalid transitions.** Anything else fails with `invalid_transition` and changes
   nothing.
7. **Unknown order.** `order_not_found: <id>`.

## Invariants

- Existing tests in `test/orders.test.js` keep passing.
- Failed transitions never mutate the order or history.
