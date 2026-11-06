import test from "node:test";
import assert from "node:assert";
import {
  acceptFollow, createUser, follow, listMessages, markRead, reset, sendMessage,
  startConversation, unreadCount,
} from "../src/messaging.js";

function setup() {
  reset();
  createUser({ id: "U1" });
  createUser({ id: "U2" });
  createUser({ id: "U3", private: true });
}

test("public users can be messaged directly", () => {
  setup();
  startConversation({ id: "C1", fromUserId: "U1", toUserId: "U2" });
  sendMessage({ conversationId: "C1", senderId: "U1", text: "hi", clientId: "a" });
  assert.deepStrictEqual(listMessages({ conversationId: "C1", userId: "U2" }).map((m) => m.text), ["hi"]);
});

test("private users need an accepted follow", () => {
  setup();
  assert.deepStrictEqual(follow({ followerId: "U1", followeeId: "U3" }), { status: "pending" });
  assert.throws(() => startConversation({ id: "C1", fromUserId: "U1", toUserId: "U3" }),
    { message: "not_allowed" });
  acceptFollow({ followerId: "U1", followeeId: "U3" });
  startConversation({ id: "C1", fromUserId: "U1", toUserId: "U3" });
  sendMessage({ conversationId: "C1", senderId: "U3", text: "hello", clientId: "a" });
  assert.strictEqual(listMessages({ conversationId: "C1", userId: "U1" }).length, 1);
});

test("non-participants cannot send, list or mark", () => {
  setup();
  startConversation({ id: "C1", fromUserId: "U1", toUserId: "U2" });
  sendMessage({ conversationId: "C1", senderId: "U1", text: "hi", clientId: "a" });
  assert.throws(() => sendMessage({ conversationId: "C1", senderId: "U3", text: "no", clientId: "b" }),
    { message: "not_participant: U3" });
  assert.throws(() => listMessages({ conversationId: "C1", userId: "U3" }),
    { message: "not_participant: U3" });
  assert.throws(() => markRead({ conversationId: "C1", seq: 1, userId: "U3" }),
    { message: "not_participant: U3" });
});

test("clientId is idempotent and sequences increase", () => {
  setup();
  startConversation({ id: "C1", fromUserId: "U1", toUserId: "U2" });
  const first = sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "same" });
  const second = sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "same" });
  assert.deepStrictEqual(second, first);
  const third = sendMessage({ conversationId: "C1", senderId: "U2", text: "two", clientId: "next" });
  assert.strictEqual(third.seq, 2);
});

test("unread excludes own and read messages", () => {
  setup();
  startConversation({ id: "C1", fromUserId: "U1", toUserId: "U2" });
  sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "a" });
  sendMessage({ conversationId: "C1", senderId: "U2", text: "two", clientId: "b" });
  assert.strictEqual(unreadCount({ conversationId: "C1", userId: "U2" }), 1);
  markRead({ conversationId: "C1", seq: 1, userId: "U2" });
  assert.strictEqual(unreadCount({ conversationId: "C1", userId: "U2" }), 0);
});

test("unknowns and validation", () => {
  setup();
  assert.throws(() => startConversation({ id: "C1", fromUserId: "U1", toUserId: "X" }),
    { message: "user_not_found: X" });
  assert.throws(() => startConversation({ id: "C1", fromUserId: "U1", toUserId: "U1" }),
    { message: "self_conversation" });
  startConversation({ id: "C1", fromUserId: "U1", toUserId: "U2" });
  assert.throws(() => startConversation({ id: "C1", fromUserId: "U1", toUserId: "U2" }),
    { message: "duplicate_conversation: C1" });
  assert.throws(() => listMessages({ conversationId: "X", userId: "U1" }),
    { message: "conversation_not_found: X" });
  assert.throws(() => markRead({ conversationId: "C1", seq: 99, userId: "U2" }),
    { message: "message_not_found: 99" });
});
