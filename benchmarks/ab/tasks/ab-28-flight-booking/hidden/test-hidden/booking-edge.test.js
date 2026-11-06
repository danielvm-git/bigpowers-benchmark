import test from "node:test";
import assert from "node:assert";
import { availableSeats, book, booking, cancel, createFlight, reset } from "../src/booking.js";

function setup(seats = 3, priceCents = 10000) {
  reset();
  createFlight({ id: "F1", seats, priceCents });
}

test("books the lowest free seat and tracks availability", () => {
  setup();
  const first = book({ idempotencyKey: "k1", flightId: "F1", passengerId: "P1" });
  const second = book({ idempotencyKey: "k2", flightId: "F1", passengerId: "P2" });
  assert.strictEqual(first.seat, 1);
  assert.strictEqual(second.seat, 2);
  assert.strictEqual(availableSeats("F1"), 1);
  assert.strictEqual(first.payment.amountCents, 10000);
});

test("sold out after all seats are taken", () => {
  setup(1);
  book({ idempotencyKey: "k1", flightId: "F1", passengerId: "P1" });
  assert.throws(() => book({ idempotencyKey: "k2", flightId: "F1", passengerId: "P2" }),
    { message: "sold_out" });
  assert.strictEqual(availableSeats("F1"), 0);
});

test("the same idempotency key never consumes a second seat", () => {
  setup();
  const first = book({ idempotencyKey: "same", flightId: "F1", passengerId: "P1" });
  const second = book({ idempotencyKey: "same", flightId: "F1", passengerId: "P1" });
  assert.deepStrictEqual(second, first);
  assert.strictEqual(availableSeats("F1"), 2);
});

test("cancelling releases the seat and refunds once", () => {
  setup();
  const created = book({ idempotencyKey: "k1", flightId: "F1", passengerId: "P1" });
  const cancelled = cancel(created.id);
  assert.strictEqual(cancelled.status, "cancelled");
  assert.strictEqual(cancelled.refund.amountCents, 10000);
  assert.strictEqual(availableSeats("F1"), 3);

  const again = cancel(created.id);
  assert.deepStrictEqual(again.refund, cancelled.refund);
  assert.strictEqual(availableSeats("F1"), 3);
});

test("a cancelled seat can be booked again", () => {
  setup(1);
  const first = book({ idempotencyKey: "k1", flightId: "F1", passengerId: "P1" });
  cancel(first.id);
  const second = book({ idempotencyKey: "k2", flightId: "F1", passengerId: "P2" });
  assert.strictEqual(second.seat, 1);
  assert.strictEqual(availableSeats("F1"), 0);
});

test("unknown flights and bookings fail", () => {
  setup();
  assert.throws(() => book({ idempotencyKey: "k1", flightId: "X", passengerId: "P" }),
    { message: "flight_not_found: X" });
  assert.throws(() => cancel("BK-999"), { message: "booking_not_found: BK-999" });
  assert.throws(() => booking("BK-999"), { message: "booking_not_found: BK-999" });
  assert.throws(() => availableSeats("X"), { message: "flight_not_found: X" });
});

test("flight and booking validation", () => {
  reset();
  assert.throws(() => createFlight({ id: "F1", seats: 0, priceCents: 1 }), { message: "invalid_seats" });
  assert.throws(() => createFlight({ id: "F1", seats: 1, priceCents: -1 }), { message: "invalid_price" });
  createFlight({ id: "F1", seats: 1, priceCents: 100 });
  assert.throws(() => createFlight({ id: "F1", seats: 1, priceCents: 100 }),
    { message: "duplicate_flight: F1" });
});

test("two bookings racing for the last seat produce one winner", async () => {
  setup(1);
  const results = await Promise.allSettled([
    Promise.resolve().then(() => book({ idempotencyKey: "a", flightId: "F1", passengerId: "P1" })),
    Promise.resolve().then(() => book({ idempotencyKey: "b", flightId: "F1", passengerId: "P2" })),
  ]);
  assert.strictEqual(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.strictEqual(results.filter((r) => r.status === "rejected").length, 1);
  assert.strictEqual(availableSeats("F1"), 0);
});
