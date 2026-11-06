# Specification: flight booking

## Overview

An in-memory flight inventory and booking system with deterministic seats, idempotent booking and
single refund on cancellation.

## API

- `createFlight({ id, seats, priceCents })`
- `book({ idempotencyKey, flightId, passengerId })`
- `cancel(bookingId)`
- `availableSeats(flightId)`
- `booking(bookingId)`
- `reset()`

## Rules

1. **Flight.** `id` is unique and non-empty; `seats` is a positive integer; `priceCents` is a
   non-negative integer. Invalid fields fail with `invalid_flight_id`, `invalid_seats` and
   `invalid_price`. Duplicate id fails with `duplicate_flight: <id>`.
2. **Book.** `idempotencyKey` is non-empty; the flight must exist; a full flight fails with
   `sold_out`; the same key returns the original booking without consuming another seat.
   A booking gets the lowest free seat number, `status: "confirmed"`, and
   `payment: { amountCents: priceCents, status: "paid" }`.
3. **Cancel.** An unknown booking fails with `booking_not_found: <id>`. A confirmed booking
   becomes `status: "cancelled"`, releases its seat, and gains
   `refund: { amountCents: priceCents, status: "refunded" }`. Cancelling again is idempotent:
   it returns the same booking and never refunds twice.
4. **Availability.** `availableSeats(flightId)` counts seats not held by a confirmed booking.
5. **Concurrency.** Two bookings racing for the last seat: exactly one succeeds, the other gets
   `sold_out`, and the seat is never double-assigned.

## Invariants

- Existing tests in `test/booking.test.js` keep passing.
- A booking and its payment are created together or not at all.
