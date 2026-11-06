# Specification: Catalog Segregation & Role Visibility

## Overview

Customers must only see products their role allows, and a hidden product must not be detectable
through errors, search results, counts or facets.

## Role hierarchy

From lowest to highest privilege:

1. `anonymous`
2. `customer`
3. `vip`
4. `internal`

A role can see a product when its `minRole` is at or below the role in this hierarchy.

## Negative overrides

A product tagged `staff_only` or `discontinued` is hidden from `anonymous`, `customer` and `vip`,
even when its `minRole` would allow it. Only `internal` sees those products.

## Anti-metadata-oracle rules

1. **A hidden product looks absent.**
   `getProductById(id, role)` throws `product not found: <id>` for a hidden product and for an id
   that does not exist. It never throws a forbidden/403 error, because that would confirm
   existence.

2. **Search cannot leak hidden items.**
   `searchProducts(query, category, role)` filters by visibility first, then by the optional
   category and query. `total` and every value in `facets` count only visible matches. Hidden
   items must not contribute to any count.

3. **Unknown ids are absent for every role.**
   The same `product not found: <id>` error is returned for an id that never existed.

## Invariants

- Anonymous users searching without restrictions still see standard public items.
- Existing tests in `test/catalog.test.js` keep passing.
