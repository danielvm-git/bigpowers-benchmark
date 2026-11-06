# Specification: cursor-paginated feed

## API

`feed({ posts, viewer, limit, cursor })` returns `{ items, nextCursor }`.

- `posts`: `{ id, author, visibility, createdAt, seq }`; `visibility` is `public`,
  `followers` or `private`; `createdAt` and `seq` are integers.
- `viewer`: `{ id, following }`; `following` is an array of author ids.
- `limit`: positive integer.
- `cursor`: optional string from a previous `nextCursor`.

## Rules

1. **Visibility.** A post is visible when it is `public`, authored by the viewer, or
   `followers` and the viewer follows the author. `private` is visible only to its author.
2. **Order.** Newest first by `createdAt`, then by `seq`, both descending.
3. **Cursor.** A cursor is `<createdAt>:<seq>`. Return only visible posts that sort strictly
   after the cursor. `nextCursor` is the last returned item's cursor, or `null` when no
   more visible posts remain.
4. **Validation.** A limit that is not a positive integer fails with `invalid_limit`.
   A malformed cursor fails with `invalid_cursor`.

## Invariants

- Existing tests in `test/feed.test.js` keep passing.
- Pagination never returns duplicates or skips a visible post.
