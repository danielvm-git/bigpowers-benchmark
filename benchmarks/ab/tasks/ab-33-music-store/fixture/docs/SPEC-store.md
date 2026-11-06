# Specification: digital music store

## API

- `createUser({ id, name })`
- `createTrack({ id, title, priceCents })`
- `createPlaylist({ id, userId, name })`
- `addTrackToPlaylist({ playlistId, trackId, userId })`
- `removeTrackFromPlaylist({ playlistId, trackId, userId })`
- `playlistTracks({ playlistId, userId })`
- `purchase({ userId, trackId, idempotencyKey })`
- `refund({ purchaseId, userId })`
- `hasEntitlement({ userId, trackId })`
- `reset()`

## Rules

1. **Playlists.** Only the owner may add, remove or list tracks; otherwise
   `not_playlist_owner`. Duplicate tracks fail with `track_already_in_playlist`; removing an
   absent track fails with `track_not_in_playlist`. `playlistTracks` preserves insertion order.
2. **Purchase.** User and track must exist; `priceCents` is a non-negative integer. The same
   `idempotencyKey` returns the original purchase; a missing or empty key fails with
   `invalid_idempotency_key`. Buying an owned track with a new key fails with
   `already_owned`. A purchase grants an entitlement and records `amountCents`.
3. **Refund.** Only the purchaser can refund (`not_purchaser`); an unknown purchase is
   `purchase_not_found: <id>`. Refunding twice is idempotent and removes the entitlement once.
4. **Errors.** Unknown user/track/playlist are `user_not_found: <id>`, `track_not_found: <id>`,
   `playlist_not_found: <id>`.

## Invariants

- Existing tests in `test/store.test.js` keep passing.
- A refunded purchase never leaves an entitlement.
