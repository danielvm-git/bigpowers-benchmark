# Specification: access policy engine

## API

`authorize(rules, request)` returns `{ allowed, rule }`.

- `rules`: `{ id, effect, action, resource, principal?, priority }`.
  `effect` is `allow` or `deny`; `priority` is an integer (higher wins); `principal`
  defaults to `*`.
- `request`: `{ action, resource, principal }`.

## Matching

A rule matches when its `action`, `resource` and `principal` each match. A pattern is
either an exact string, `*`, or a prefix ending in `*` (for example `read*`).
Prefix wildcards match the prefix and anything after it.

## Precedence

1. Highest `priority` wins.
2. On equal priority, `deny` wins over `allow`.
3. On equal priority and effect, the lexicographically smaller rule id wins.
4. If no rule matches, deny with `rule: null`.

## Validation

- Duplicate ids fail with `duplicate_rule: <id>`.
- Invalid rules fail with `invalid_rule: <id>`.
- Invalid requests fail with `invalid_request`.

## Invariants

- Existing tests in `test/policy.test.js` keep passing.
- A denied request never returns a matching allow rule.
