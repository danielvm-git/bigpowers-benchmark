# Specification: Inventory Reservations

## Overview

Checkout can hold stock temporarily while a customer finishes payment. A hold never changes
permanent stock until it is confirmed.

## Behaviour

1. **Time comes from the provided clock.**
   Every time check observes the clock injected at `src/clock.js`. Advancing the clock must change
   availability and expiry; the wall clock is never consulted.

2. **A hold lasts 15 minutes.**
   A reservation is active from creation until 15 minutes have elapsed on the injected clock.
   At exactly 15 minutes it is expired: availability is restored and confirming it fails.

3. **Availability is stock minus active holds.**
   `getItem(id)` reports the permanent `stock` and an `available` count. Only active,
   unconfirmed, uncancelled holds reduce `available`. Expired, confirmed and cancelled holds do
   not.

4. **Creating a reservation (`createReservation(id, itemId, qty)`).**
   - `qty` must be a positive number; otherwise it fails.
   - It fails when the requested quantity exceeds `available`, with
     `insufficient stock for reservation: <itemId>`.
   - A successful call returns the reservation: `id`, `itemId`, `qty`, `status: "active"` and
     `expiresAt`. Permanent stock is unchanged.

5. **Confirming a reservation (`confirmReservation(id)`).**
   - An unknown id fails with `reservation not found: <id>`.
   - An expired reservation, or one that is not active, fails with
     `reservation expired or closed: <id>`.
   - A successful confirmation marks the reservation `"confirmed"`, permanently reduces stock by
     its quantity, and returns the updated reservation.

6. **Cancelling a reservation (`cancelReservation(id)`).**
   - An unknown id fails with `reservation not found: <id>`.
   - Cancelling an active reservation marks it `"cancelled"` and releases its hold.
   - Cancelling an already cancelled reservation succeeds and changes nothing (idempotent).

7. **Reset (`resetReservations()`).**
   Clears all reservation state for tests.

## Invariants

- Existing tests in `test/inventory.test.js` keep passing.
- An item that is not found keeps its existing `item not found: <id>` error.
- Confirm then cancel does not restore stock twice.
