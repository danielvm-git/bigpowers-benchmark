# Specification: binary frame protocol

## Frame

Every message, in both directions, is:

```
4-byte unsigned big-endian length | UTF-8 JSON body
```

The length is the body length only. Bodies can be split across TCP writes or contain several
frames in one write; the reader must buffer until each complete frame arrives.

## Commands

| Body | Response |
|---|---|
| `{"cmd":"set","key":string,"value":any}` | `{"ok":true}` |
| `{"cmd":"get","key":string}` | `{"ok":true,"value":any}` or `{"ok":true,"value":null}` |
| `{"cmd":"del","key":string}` | `{"ok":true,"removed":boolean}` |
| `{"cmd":"quit"}` | close the connection |

- The maximum body size is 1 MiB. A larger frame returns
  `{"ok":false,"error":"frame_too_large"}` and closes the connection.
- Malformed JSON returns `{"ok":false,"error":"invalid_json"}`.
- Unknown commands return `{"ok":false,"error":"unknown_command"}`.
- A command with a missing/invalid key returns `{"ok":false,"error":"invalid_request"}`.
- All clients share the same store.

## Invariants

- A partial frame never produces a response.
- Two frames in one write produce two responses, in order.
- Existing tests in `test/server.test.js` keep passing.
