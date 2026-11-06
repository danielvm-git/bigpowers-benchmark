import test from "node:test";
import assert from "node:assert";
import { availableSeats, book, createFlight, reset } from "../src/booking.js";

test("creates a flight and books seats", () => {
  reset();
  createFlight({ id: "F1", seats: 3, priceCents: 10000 });
  const booking = book({ idempotencyKey: "visible-1", flightId: "F1", passengerId: "P1" });
  assert.ok(booking.id);
  assert.strictEqual(availableSeats("F1"), 2);
});
