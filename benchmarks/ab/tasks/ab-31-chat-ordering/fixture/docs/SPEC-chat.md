# Specification: chat ordering and delivery

## Overview

An in-memory chat with per-conversation sequence numbers, client idempotency, delivery/read state,
unread counts and presence with a timeout.

## API

- `createConversation({ id, participants })`
- `sendMessage({ conversationId, senderId, text, clientId })`
- `listMessages({ conversationId, afterSeq = 0 })`
- `markDelivered({ conversationId, seq, userId })`
- `markRead({ conversationId, seq, userId })`
- `unreadCount({ conversationId, userId })`
- `setPresence({ conversationId, userId, online, lastSeen })`
- `getPresence({ conversationId, userId, now })`
- `reset()`

## Rules

1. **Conversation.** Unique id; a non-empty list of unique participants. A duplicate id fails with
   `duplicate_conversation: <id>`; an invalid id with `invalid_conversation_id`; empty or duplicate
   participants with `invalid_participants`.
2. **Send.** The conversation and sender must exist and the sender must be a participant; `text` is
   a non-empty string; `clientId` is a non-empty string. Unknown conversation fails with
   `conversation_not_found: <id>`, a non-participant with `not_participant: <id>`.
   Empty text fails with `invalid_text`; an empty `clientId` with `invalid_client_id`.
   The same `clientId` in the same conversation returns the original message and never consumes a
   new sequence number.
3. **Ordering.** Each conversation has a monotonically increasing `seq` starting at 1.
   `listMessages` returns `seq > afterSeq` in ascending order, as copies.
4. **Delivery/read.** `markDelivered` and `markRead` are idempotent. `markRead` also marks the
   message delivered. An unknown message fails with `message_not_found: <seq>`; a non-participant
   fails with `not_participant: <id>`.
5. **Unread.** `unreadCount` counts messages not read by the user, excluding messages the user sent.
6. **Presence.** `online` with `now - lastSeen < 60000` is `"online"`; otherwise `"offline"`.
   A non-boolean `online` or non-finite `lastSeen` fails with `invalid_presence`; a non-finite
   `now` fails with `invalid_now`.

## Invariants

- Existing tests in `test/chat.test.js` keep passing.
- A failed send does not consume a sequence number.
