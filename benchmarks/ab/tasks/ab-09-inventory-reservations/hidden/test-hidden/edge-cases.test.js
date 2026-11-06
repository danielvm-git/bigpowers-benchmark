import test from "node:test";
import assert from "node:assert";
import { clock } from "../src/clock.js";
import { getItem, resetInventory } from "../src/inventory.js";
import {
  createReservation,
  confirmReservation,
  cancelReservation,
  resetReservations,
} from "../src/reservations.js";

test.beforeEach(() => {
  clock.reset();
  resetInventory();
  resetReservations();
});

test("rejects zero and negative quantities", () => {
  assert.throws(() => createReservation("R-0", "ITEM-101", 0), { message: /positive/ });
  assert.throws(() => createReservation("R-negative", "ITEM-101", -1), { message: /positive/ });
  assert.strictEqual(getItem("ITEM-101").available, 10);
});

test("unknown reservation ids fail on confirm and cancel", () => {
  assert.throws(() => confirmReservation("MISSING"), { message: "reservation not found: MISSING" });
  assert.throws(() => cancelReservation("MISSING"), { message: "reservation not found: MISSING" });
});

test("confirming an already confirmed reservation fails", () => {
  createReservation("R-1", "ITEM-102", 1);
  confirmReservation("R-1");
  assert.throws(() => confirmReservation("R-1"), { message: /reservation expired or closed/ });
  assert.strictEqual(getItem("ITEM-102").stock, 4);
});

test("a hold expires exactly at 15 minutes", () => {
  createReservation("R-2", "ITEM-101", 4);
  assert.strictEqual(getItem("ITEM-101").available, 6);
  clock.advance(900000);
  assert.strictEqual(getItem("ITEM-101").available, 10);
  assert.throws(() => confirmReservation("R-2"), { message: /reservation expired or closed/ });
});

test("cancelling releases the hold but never changes permanent stock", () => {
  createReservation("R-3", "ITEM-101", 3);
  cancelReservation("R-3");
  const item = getItem("ITEM-101");
  assert.strictEqual(item.stock, 10);
  assert.strictEqual(item.available, 10);
  assert.throws(() => confirmReservation("R-3"), { message: /reservation expired or closed/ });
});

test("stock released by an expiry can be reserved again", () => {
  createReservation("R-4", "ITEM-102", 5);
  assert.strictEqual(getItem("ITEM-102").available, 0);
  clock.advance(900000);
  createReservation("R-5", "ITEM-102", 5);
  assert.strictEqual(getItem("ITEM-102").available, 0);
});
