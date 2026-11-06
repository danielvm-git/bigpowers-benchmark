# Specification: items API partial updates

## Existing behaviour

`GET /items` returns `{ items: [...] }`; `GET /items/:id` returns one item or the shared
`not_found` error; `POST /items` creates an item after validation. Errors always have the shape:

```
{ "error": { "code": "...", "message": "..." } }
```

## New behaviour: `PATCH /items/:id`

- Accepts a partial update of `name`, `priceCents` and `quantity`. Any field that is omitted keeps
  its current value.
- Unknown fields are ignored, not rejected.
- A body with no editable field fails with `400`, code `invalid_input`, message
  `no fields to update`.
- Invalid values use the same rules and messages as `POST /items`.
- An unknown id fails with `404`, code `not_found`, message `item not found: <id>`.
- A success returns `200` and the updated item.

## Invariants

- Existing `GET` and `POST` behaviour is unchanged.
- `test/items.test.js` keeps passing.
- Malformed JSON is a `400 invalid_input`, never a crash.
