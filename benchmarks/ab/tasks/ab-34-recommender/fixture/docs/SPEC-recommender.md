# Specification: recommendation engine

## API

- `recordInteraction({ userId, itemId, type = "view", weight })`
- `recommend({ userId, limit = 5 })`
- `bucket({ userId, experiment })`
- `reset()`

## Rules

1. **Interactions.** `userId` and `itemId` are non-empty strings. `type` is `view` (default
   weight 1), `like` (3) or `purchase` (5). An explicit `weight` is a positive finite number and
   overrides the type default. Anything else fails with `invalid_interaction_type`,
   `invalid_weight`, `invalid_user_id` or `invalid_item_id`. Repeated interactions accumulate
   their weights.
2. **Recommend.** Look at the items the user touched. For every other user who touched one of
   those items, every item that user touched is a candidate. A candidate's score is the sum of
   `seedWeight * candidateWeight` over those co-occurrences. Items the user already touched are
   excluded. Sort by score descending, then itemId ascending. If the user has no interactions,
   return popular items by total weight descending, then itemId. `limit` is a positive integer.
3. **Buckets.** `bucket({ userId, experiment })` is a deterministic integer 0–99 derived from both
   strings. The same pair always gives the same bucket; different experiments normally differ.

## Invariants

- Existing tests in `test/recommender.test.js` keep passing.
- A recommendation never includes an item the user already touched.
