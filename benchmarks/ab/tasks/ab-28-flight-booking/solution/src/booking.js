const flights = new Map();
const bookings = new Map();
const idempotency = new Map();
let nextBookingId = 1;

export function reset() {
  flights.clear();
  bookings.clear();
  idempotency.clear();
  nextBookingId = 1;
}

function fail(code) {
  throw new Error(code);
}

function requireFlight(id) {
  const flight = flights.get(id);
  if (!flight) fail(`flight_not_found: ${id}`);
  return flight;
}

export function createFlight({ id, seats, priceCents }) {
  if (typeof id !== "string" || !id) fail("invalid_flight_id");
  if (flights.has(id)) fail(`duplicate_flight: ${id}`);
  if (!Number.isInteger(seats) || seats <= 0) fail("invalid_seats");
  if (!Number.isInteger(priceCents) || priceCents < 0) fail("invalid_price");
  const flight = { id, seats, priceCents, taken: new Set() };
  flights.set(id, flight);
  return { id, seats, priceCents };
}

export function availableSeats(flightId) {
  const flight = requireFlight(flightId);
  return flight.seats - flight.taken.size;
}

export function book({ idempotencyKey, flightId, passengerId }) {
  if (typeof idempotencyKey !== "string" || !idempotencyKey.trim()) fail("invalid_idempotency_key");
  if (idempotency.has(idempotencyKey)) return { ...idempotency.get(idempotencyKey) };
  const flight = requireFlight(flightId);

  let seat = null;
  for (let candidate = 1; candidate <= flight.seats; candidate += 1) {
    if (!flight.taken.has(candidate)) { seat = candidate; break; }
  }
  if (seat === null) fail("sold_out");

  const booking = {
    id: `BK-${nextBookingId++}`,
    flightId,
    passengerId,
    seat,
    status: "confirmed",
    payment: { amountCents: flight.priceCents, status: "paid" },
    refund: null,
  };
  flight.taken.add(seat);
  bookings.set(booking.id, booking);
  idempotency.set(idempotencyKey, booking);
  return { ...booking };
}

export function cancel(bookingId) {
  const booking = bookings.get(bookingId);
  if (!booking) fail(`booking_not_found: ${bookingId}`);
  if (booking.status === "cancelled") return { ...booking };

  booking.status = "cancelled";
  booking.refund = { amountCents: booking.payment.amountCents, status: "refunded" };
  const flight = flights.get(booking.flightId);
  if (flight) flight.taken.delete(booking.seat);
  return { ...booking };
}

export function booking(bookingId) {
  const found = bookings.get(bookingId);
  if (!found) fail(`booking_not_found: ${bookingId}`);
  return { ...found };
}
