import test from "node:test";
import assert from "node:assert";
import {
  addTrackToPlaylist, createPlaylist, createTrack, createUser, hasEntitlement, playlistTracks,
  purchase, refund, removeTrackFromPlaylist, reset,
} from "../src/store.js";

function setup() {
  reset();
  createUser({ id: "U1", name: "Ana" });
  createUser({ id: "U2", name: "Bruno" });
  createTrack({ id: "T1", title: "One", priceCents: 100 });
  createTrack({ id: "T2", title: "Two", priceCents: 200 });
  createPlaylist({ id: "P1", userId: "U1", name: "Favs" });
}

test("only the owner can change or read a playlist", () => {
  setup();
  addTrackToPlaylist({ playlistId: "P1", trackId: "T1", userId: "U1" });
  assert.deepStrictEqual(playlistTracks({ playlistId: "P1", userId: "U1" }), ["T1"]);
  assert.throws(() => addTrackToPlaylist({ playlistId: "P1", trackId: "T2", userId: "U2" }),
    { message: "not_playlist_owner" });
  assert.throws(() => playlistTracks({ playlistId: "P1", userId: "U2" }),
    { message: "not_playlist_owner" });
  assert.throws(() => removeTrackFromPlaylist({ playlistId: "P1", trackId: "T1", userId: "U2" }),
    { message: "not_playlist_owner" });
});

test("duplicate and missing playlist tracks fail", () => {
  setup();
  addTrackToPlaylist({ playlistId: "P1", trackId: "T1", userId: "U1" });
  assert.throws(() => addTrackToPlaylist({ playlistId: "P1", trackId: "T1", userId: "U1" }),
    { message: "track_already_in_playlist" });
  assert.throws(() => removeTrackFromPlaylist({ playlistId: "P1", trackId: "T2", userId: "U1" }),
    { message: "track_not_in_playlist" });
});

test("purchase is idempotent and grants an entitlement", () => {
  setup();
  const first = purchase({ userId: "U1", trackId: "T1", idempotencyKey: "k1" });
  const second = purchase({ userId: "U1", trackId: "T1", idempotencyKey: "k1" });
  assert.deepStrictEqual(second, first);
  assert.strictEqual(first.amountCents, 100);
  assert.strictEqual(hasEntitlement({ userId: "U1", trackId: "T1" }), true);
});

test("buying owned with a new key fails", () => {
  setup();
  purchase({ userId: "U1", trackId: "T1", idempotencyKey: "k1" });
  assert.throws(() => purchase({ userId: "U1", trackId: "T1", idempotencyKey: "k2" }),
    { message: "already_owned" });
});

test("refund is single, removes entitlement and requires the purchaser", () => {
  setup();
  const record = purchase({ userId: "U1", trackId: "T1", idempotencyKey: "k1" });
  assert.throws(() => refund({ purchaseId: record.id, userId: "U2" }), { message: "not_purchaser" });
  const first = refund({ purchaseId: record.id, userId: "U1" });
  assert.strictEqual(first.status, "refunded");
  assert.strictEqual(hasEntitlement({ userId: "U1", trackId: "T1" }), false);
  const again = refund({ purchaseId: record.id, userId: "U1" });
  assert.deepStrictEqual(again, first);
});

test("unknown entities and validation", () => {
  setup();
  assert.throws(() => purchase({ userId: "X", trackId: "T1", idempotencyKey: "k" }),
    { message: "user_not_found: X" });
  assert.throws(() => purchase({ userId: "U1", trackId: "X", idempotencyKey: "k" }),
    { message: "track_not_found: X" });
  assert.throws(() => purchase({ userId: "U1", trackId: "T1" }),
    { message: "invalid_idempotency_key" });
  assert.throws(() => refund({ purchaseId: "X", userId: "U1" }),
    { message: "purchase_not_found: X" });
  assert.throws(() => addTrackToPlaylist({ playlistId: "X", trackId: "T1", userId: "U1" }),
    { message: "playlist_not_found: X" });
});
