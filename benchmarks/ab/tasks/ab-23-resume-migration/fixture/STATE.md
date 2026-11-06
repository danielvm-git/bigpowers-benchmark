# Migration state

- Step 1 — normalize orders: **done** (`data/orders.normalized.json`)
- Step 2 — build the customer index: **done** (`data/customers.index.json`)
- Step 3 — build the summary: **pending** (`data/summary.json`)

Do not redo completed steps. A step is complete when it is listed in
`data/migration-state.json` **and** its output file exists. If an output is missing, that step
must run again. The summary has exactly this shape:

```json
{ "orderCount": 3, "customerCount": 2, "revenueCents": 2700 }
```

`orderCount` is the number of normalized orders, `customerCount` is the number of indexed
customers, and `revenueCents` is the sum of the normalized orders' `totalCents`.
