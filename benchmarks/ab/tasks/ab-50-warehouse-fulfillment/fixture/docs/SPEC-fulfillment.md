# Specification: multi-warehouse fulfillment

## API

`reset()`, `addWarehouse({ id, priority })`, `setStock({ warehouseId, sku, qty })`,
`placeOrder({ id, items })`, `fulfill({ id })`, `cancel({ id })`,
`order(id)`, `available(sku)`.

## Rules

1. **Warehouses.** Unique id; `priority` is an integer (lower is preferred). A duplicate fails
   with `duplicate_warehouse: <id>`. Unknown warehouse fails with `warehouse_not_found: <id>`.
2. **Stock.** `qty` is a non-negative integer. Setting stock below the quantity already
   reserved fails with `stock_below_reserved` and changes nothing.
3. **Orders.** Unique id; `items` is a non-empty array of `{ sku, qty }` with unique skus and
   positive integer quantities. A duplicate fails with `duplicate_order: <id>`; invalid items
   fail with `invalid_order`.
4. **Allocation.** For each item, visit warehouses by `priority` ascending, then `id`
   ascending, and reserve `min(remaining, available)` from each. Available stock is physical
   stock minus reservations. If an item cannot be fully allocated, reserve what is available,
   record the shortfall in `backordered`, and set the order `backordered`; otherwise `allocated`.
5. **Atomicity.** A rejected `placeOrder` changes no stock, reservation or order.
6. **Fulfill.** Only `allocated` orders can be fulfilled: physical stock drops by the
   allocations, reservations clear, and the order becomes `fulfilled`. `backordered` and
   `fulfilled` fail with `invalid_transition`.
7. **Cancel.** `allocated` and `backordered` orders can be cancelled; reservations release and
   the order becomes `cancelled`. `fulfilled` fails with `invalid_transition`.
8. **Lookup.** Unknown order fails with `order_not_found: <id>`. `order(id)` returns
   `{ id, status, allocations, backordered }`.

## Invariants

- Existing tests in `test/fulfillment.test.js` keep passing.
- Reserved stock is never fulfilled twice and stock never goes negative.
