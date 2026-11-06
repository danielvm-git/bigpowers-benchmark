import test from "node:test";
import assert from "node:assert";
import { createUser, listMessages, reset, sendMessage, startConversation } from "../src/messaging.js";
test("starts a conversation and sends a message", () => {
  reset();
  createUser({ id: "U1" }); createUser({ id: "U2" });
  startConversation({ id: "C1", fromUserId: "U1", toUserId: "U2" });
  sendMessage({ conversationId: "C1", senderId: "U1", text: "hi", clientId: "a" });
  assert.strictEqual(listMessages({ conversationId: "C1", userId: "U2" }).length, 1);
});
