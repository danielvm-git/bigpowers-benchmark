# Specification: mini Redis with a sorted set

## Overview

A small TCP server speaking a line protocol. It stores strings and sorted sets in memory and
serves multiple clients at once.

## Protocol

One command per line. Arguments are separated by whitespace. `SET` takes the rest of the line as
the value, so a value may contain spaces. Every response is one line ending in `\n`.
Empty lines are ignored. Partial frames are buffered until a newline arrives.

## Commands

| Command | Response |
|---|---|
| `PING` | `PONG` |
| `SET key value...` | `OK` |
| `GET key` | value or `(nil)` |
| `DEL key` | `1` or `0` |
| `ZADD key score member` | `1` if new, `0` if the score was updated |
| `ZSCORE key member` | score or `(nil)` |
| `ZRANGE key start stop` | JSON array of members |
| `ZREM key member` | `1` or `0` |
| `ZCARD key` | number of members |
| `QUIT` | close the connection without a response |

## Rules

- Scores are non-negative integers. A non-integer or negative score is
  `ERR invalid score: <value>`.
- `ZRANGE` sorts by score ascending, then member lexicographically ascending.
  Indices are inclusive. A negative index counts from the end. Out-of-range bounds are clamped;
  `start > stop` returns `[]`.
- Strings and sorted sets share a key space. Using a string command on a sorted-set key, or a
  sorted-set command on a string key, returns
  `WRONGTYPE operation against a key holding the wrong kind of value`.
- Unknown commands return `ERR unknown command: <command>`.
- Wrong arity returns `ERR wrong number of arguments for '<command>'`.
- All clients share the same store.

## Invariants

- A partial command never produces a response.
- Multiple commands sent in one write produce one response per command, in order.
- Existing tests in `test/server.test.js` keep passing.
