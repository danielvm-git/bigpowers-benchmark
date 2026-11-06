# Specification: URL shortener API

## Overview

A small HTTP API that turns a long URL into a short code, redirects that code, and records
basic metadata. The store is in memory.

## Endpoints

### `POST /links`

Body: `{ "url": string, "alias"?: string, "expiresAt"?: string }`.

- `url` must be an absolute `http` or `https` URL, at most 2048 characters. Anything else is
  `400 invalid_url`.
- `alias` is optional. When present it must match `[A-Za-z0-9_-]{3,32}`; anything else is
  `400 invalid_alias`. An alias already in use is `409 alias_taken`.
- `expiresAt` is optional ISO-8601. It must parse and be in the future; otherwise
  `400 invalid_expiry`.
- Without an alias the API generates a six-character `[A-Za-z0-9]` code that is not in use.
- Success is `201` with `{ code, url, alias, createdAt, expiresAt, clicks, expired }`.

### `GET /links`

`200 { links: [...] }` in creation order. Each item has the same shape as the create response.

### `GET /links/:code`

`200` with the link metadata; `404 not_found` when the code does not exist.
An expired link is still readable here and reports `expired: true`.

### `DELETE /links/:code`

`204` with no body; `404 not_found` when the code does not exist.

### `GET /:code`

`302` to the original URL and increments `clicks`. An unknown code is `404 not_found`.
An expired code is `410 expired` and does not increment clicks.

## Errors

Every error uses:

```json
{ "error": { "code": "invalid_url", "message": "..." } }
```

Malformed JSON is `400 invalid_input`. Unknown routes are `404 not_found`.

## Invariants

- Click counts change only on a successful redirect.
- Metadata and list reads never change the click count.
- Expiry is evaluated at request time.
- Existing tests in `test/shortener.test.js` keep passing.
