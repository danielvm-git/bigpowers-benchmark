import test from "node:test";
import assert from "node:assert";
import {
  createConversation, getPresence, listMessages, markDelivered, markRead, reset, sendMessage,
  setPresence, unreadCount,
} from "../src/chat.js";

function setup() {
  reset();
  createConversation({ id: "C1", participants: ["U1", "U2"] });
}

test("messages get increasing sequence numbers and afterSeq paginates", () => {
  setup();
  sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "a" });
  sendMessage({ conversationId: "C1", senderId: "U2", text: "two", clientId: "b" });
  sendMessage({ conversationId: "C1", senderId: "U1", text: "three", clientId: "c" });
  assert.deepStrictEqual(listMessages({ conversationId: "C1" }).map((m) => m.seq), [1, 2, 3]);
  assert.deepStrictEqual(
    listMessages({ conversationId: "C1", afterSeq: 1 }).map((m) => m.text), ["two", "three"]);
});

test("clientId is idempotent and a failed send consumes no sequence", () => {
  setup();
  const first = sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "same" });
  const second = sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "same" });
  assert.deepStrictEqual(second, first);
  assert.strictEqual(listMessages({ conversationId: "C1" }).length, 1);

  assert.throws(() => sendMessage({ conversationId: "C1", senderId: "U3", text: "x", clientId: "z" }),
    { message: "not_participant: U3" });
  const next = sendMessage({ conversationId: "C1", senderId: "U2", text: "two", clientId: "next" });
  assert.strictEqual(next.seq, 2);
});

test("delivery and read are idempotent and read implies delivered", () => {
  setup();
  const message = sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "a" });
  markDelivered({ conversationId: "C1", seq: message.seq, userId: "U2" });
  markDelivered({ conversationId: "C1", seq: message.seq, userId: "U2" });
  const read = markRead({ conversationId: "C1", seq: message.seq, userId: "U2" });
  assert.deepStrictEqual(read.deliveredTo, ["U2"]);
  assert.deepStrictEqual(read.readBy, ["U2"]);
});

test("unread excludes own and read messages", () => {
  setup();
  const first = sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "a" });
  sendMessage({ conversationId: "C1", senderId: "U2", text: "two", clientId: "b" });
  sendMessage({ conversationId: "C1", senderId: "U1", text: "three", clientId: "c" });
  assert.strictEqual(unreadCount({ conversationId: "C1", userId: "U2" }), 2);
  markRead({ conversationId: "C1", seq: first.seq, userId: "U2" });
  assert.strictEqual(unreadCount({ conversationId: "C1", userId: "U2" }), 1);
});

test("presence is online only inside the 60 second window", () => {
  setup();
  setPresence({ conversationId: "C1", userId: "U1", online: true, lastSeen: 1000 });
  assert.strictEqual(getPresence({ conversationId: "C1", userId: "U1", now: 60999 }), "online");
  assert.strictEqual(getPresence({ conversationId: "C1", userId: "U1", now: 61000 }), "offline");
  setPresence({ conversationId: "C1", userId: "U1", online: false, lastSeen: 61000 });
  assert.strictEqual(getPresence({ conversationId: "C1", userId: "U1", now: 61001 }), "offline");
});

test("unknown conversations, messages and users fail", () => {
  setup();
  assert.throws(() => listMessages({ conversationId: "X" }),
    { message: "conversation_not_found: X" });
  assert.throws(() => markDelivered({ conversationId: "C1", seq: 99, userId: "U2" }),
    { message: "message_not_found: 99" });
  assert.throws(() => markDelivered({ conversationId: "C1", seq: 1, userId: "U3" }),
    { message: "not_participant: U3" });
  assert.throws(() => unreadCount({ conversationId: "C1", userId: "U3" }),
    { message: "not_participant: U3" });
});

test("conversation validation", () => {
  reset();
  assert.throws(() => createConversation({ id: "C1", participants: [] }),
    { message: "invalid_participants" });
  createConversation({ id: "C1", participants: ["U1", "U2"] });
  assert.throws(() => createConversation({ id: "C1", participants: ["U3"] }),
    { message: "duplicate_conversation: C1" });
  assert.throws(() => createConversation({ id: "C2", participants: ["U1", "U1"] }),
    { message: "invalid_participants" });
});

test("listMessages returns copies", () => {
  setup();
  sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "a" });
  const [message] = listMessages({ conversationId: "C1" });
  message.deliveredTo.push("hacked");
  assert.deepStrictEqual(listMessages({ conversationId: "C1" })[0].deliveredTo, []);
});
