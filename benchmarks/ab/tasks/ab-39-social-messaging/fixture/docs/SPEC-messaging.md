# Specification: social messaging

## API

- `createUser({ id, private = false })`
- `follow({ followerId, followeeId })`
- `acceptFollow({ followerId, followeeId })`
- `startConversation({ id, fromUserId, toUserId })`
- `sendMessage({ conversationId, senderId, text, clientId })`
- `listMessages({ conversationId, userId, afterSeq = 0 })`
- `markDelivered({ conversationId, seq, userId })`
- `markRead({ conversationId, seq, userId })`
- `unreadCount({ conversationId, userId })`
- `reset()`

## Rules

1. **Contact.** Starting a conversation with a public user is allowed. A private user requires an
   accepted follow; a pending or absent follow fails with `not_allowed`. Self-conversation fails
   with `self_conversation`. Duplicate id fails with `duplicate_conversation: <id>`.
2. **Messages.** Only participants can send or list (`not_participant: <id>`). `clientId` is
   idempotent per conversation; text is non-empty; sequences increase from 1.
   `listMessages` returns `seq > afterSeq` ascending.
3. **Delivery/read.** Participant only; unknown message `message_not_found: <seq>`; `markRead`
   also marks delivered; both are idempotent.
4. **Unread.** Counts messages not read by the user and not sent by the user.
5. **Unknowns.** `user_not_found: <id>`, `conversation_not_found: <id>`.

## Invariants

- Existing tests in `test/messaging.test.js` keep passing.
- A pending follow never allows starting a conversation.
