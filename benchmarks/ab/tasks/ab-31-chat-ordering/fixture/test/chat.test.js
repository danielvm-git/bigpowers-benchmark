import test from "node:test";
import assert from "node:assert";
import { createConversation, listMessages, markDelivered, reset, sendMessage } from "../src/chat.js";

test("sends and lists messages in order", () => {
  reset();
  createConversation({ id: "C1", participants: ["U1", "U2"] });
  sendMessage({ conversationId: "C1", senderId: "U1", text: "one", clientId: "a" });
  sendMessage({ conversationId: "C1", senderId: "U2", text: "two", clientId: "b" });
  assert.deepStrictEqual(listMessages({ conversationId: "C1" }).map((m) => m.seq), [1, 2]);
  assert.strictEqual(markDelivered({ conversationId: "C1", seq: 1, userId: "U2" }).deliveredTo[0], "U2");
});
