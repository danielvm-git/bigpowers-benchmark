const flights = new Map();
const bookings = new Map();
let nextBookingId = 1;

export function reset() {
  flights.clear();
  bookings.clear();
  nextBookingId = 1;
}

export function createFlight({ id, seats, priceCents }) {
  const flight = { id, seats, priceCents, booked: 0 };
  flights.set(id, flight);
  return { ...flight };
}

export function availableSeats(flightId) {
  const flight = flights.get(flightId);
  return flight.seats - flight.booked;
}

export function book({ flightId, passengerId }) {
  const flight = flights.get(flightId);
  flight.booked += 1;
  const booking = { id: `BK-${nextBookingId++}`, flightId, passengerId };
  bookings.set(booking.id, booking);
  return { ...booking };
}

export function cancel(bookingId) {
  bookings.delete(bookingId);
  return { id: bookingId, status: "cancelled" };
}
