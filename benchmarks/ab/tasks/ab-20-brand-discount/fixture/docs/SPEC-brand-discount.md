# Specification: Brand-Specific Percentage Discount

## Background

The shop is adding brand-specific percentage discounts, for example 20% off every Acme product.
The new rule must not disturb existing discounts, tax or shipping.

## Behaviour

1. **Brands are visible on order lines.**
   A catalog product may carry an optional `brand`. Every priced order line exposes the product's
   brand, or `null` when the product has none. Brand matching is case-sensitive.

2. **New codes.**
   - `ACME20`: 20% off lines whose brand is exactly `acme` (lowercase), but only when that
     brand subtotal is at least €30.00.
   - `ZENITH15`: 15% off lines whose brand is exactly `zenith` (lowercase), with no minimum.

3. **Applying a brand percentage.**
   - Only lines of the rule's brand receive the discount. Every other line receives zero discount.
   - With no line of that brand, fail with
     `discount code <CODE> needs items from brand: <brand>`.
   - When the rule has a minimum and the brand subtotal is below it, fail with
     `discount code <CODE> needs a brand subtotal of at least <amount>` where the amount is the
     formatted minimum in EUR.
   - Otherwise the discount is the rule's percentage of the brand subtotal, rounded to the nearest
     cent, and is allocated only across the matching brand lines. The line discounts add up to the
     reported total.

4. **Tax follows the discount.**
   Each line is taxed on its discounted amount, not its full amount. Shipping and gift wrap keep
   their current rules.

## Invariants

- `SPRING10`, `FIVEOFF`, `BOGO-BOOKS` and `BULK` behave exactly as before.
- Tax and shipping calculations remain intact.
- Unknown discount codes keep their existing error.
- Existing tests in `test/orders.test.js` keep passing.
