import test from "node:test";
import assert from "node:assert";
import { addTrackToPlaylist, createPlaylist, createTrack, createUser, hasEntitlement, purchase, reset } from "../src/store.js";
test("playlists and purchases", () => {
  reset();
  createUser({ id: "U1", name: "Ana" });
  createTrack({ id: "T1", title: "Song", priceCents: 100 });
  createPlaylist({ id: "P1", userId: "U1", name: "Favs" });
  addTrackToPlaylist({ playlistId: "P1", trackId: "T1", userId: "U1" });
  purchase({ userId: "U1", trackId: "T1", idempotencyKey: "k1" });
  assert.strictEqual(hasEntitlement({ userId: "U1", trackId: "T1" }), true);
});
