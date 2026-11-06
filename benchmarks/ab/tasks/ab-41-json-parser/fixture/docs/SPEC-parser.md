# Specification: JSON parser

## API

`parse(text)` returns the JavaScript value or throws a `ParseError` with:

- `message` — human-readable;
- `position` — the 0-based index of the first unexpected character, or `text.length` for an
  unexpected end of input.

## Grammar

Support RFC 8259 JSON:

- whitespace: space, tab, CR, LF;
- `null`, `true`, `false`;
- numbers: optional `-`, no leading `+`, no leading zero, optional fraction and exponent;
- strings: double quotes, escapes `\" \\ \/ \b \f \n \r \t \uXXXX`; a high surrogate must be
  followed by a low surrogate; lone surrogates and raw control characters are rejected;
- arrays and objects, with no trailing commas and no comments;
- duplicate object keys keep the last value;
- trailing content after the value is an error.

## Errors

`ParseError` has `name === "ParseError"` and the `position` described above.

## Invariants

- Existing tests in `test/parser.test.js` keep passing.
- Valid JSON round-trips to the same value as `JSON.parse`.
