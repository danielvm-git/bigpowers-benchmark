const conversations = new Map();

export function reset() {
  conversations.clear();
}

function fail(code) {
  throw new Error(code);
}

function requireConversation(id) {
  const conversation = conversations.get(id);
  if (!conversation) fail(`conversation_not_found: ${id}`);
  return conversation;
}

function requireParticipant(conversation, userId) {
  if (!conversation.participants.has(userId)) fail(`not_participant: ${userId}`);
}

function findMessage(conversation, seq) {
  const message = conversation.messages.find((item) => item.seq === seq);
  if (!message) fail(`message_not_found: ${seq}`);
  return message;
}

export function createConversation({ id, participants }) {
  if (typeof id !== "string" || !id) fail("invalid_conversation_id");
  if (conversations.has(id)) fail(`duplicate_conversation: ${id}`);
  if (!Array.isArray(participants) || participants.length === 0) fail("invalid_participants");
  const unique = [...new Set(participants)];
  if (unique.length !== participants.length) fail("invalid_participants");
  const conversation = {
    id,
    participants: new Set(unique),
    messages: [],
    nextSeq: 1,
    byClientId: new Map(),
    presence: new Map(),
  };
  conversations.set(id, conversation);
  return { id, participants: [...unique] };
}

export function sendMessage({ conversationId, senderId, text, clientId }) {
  const conversation = requireConversation(conversationId);
  requireParticipant(conversation, senderId);
  if (typeof text !== "string" || !text.trim()) fail("invalid_text");
  if (typeof clientId !== "string" || !clientId.trim()) fail("invalid_client_id");
  if (conversation.byClientId.has(clientId)) {
    return { ...conversation.byClientId.get(clientId) };
  }

  const message = {
    id: `M-${conversation.nextSeq}`,
    seq: conversation.nextSeq,
    senderId,
    text,
    deliveredTo: [],
    readBy: [],
  };
  conversation.nextSeq += 1;
  conversation.messages.push(message);
  conversation.byClientId.set(clientId, message);
  return { ...message };
}

export function listMessages({ conversationId, afterSeq = 0 }) {
  const conversation = requireConversation(conversationId);
  return conversation.messages
    .filter((message) => message.seq > afterSeq)
    .map((message) => ({ ...message, deliveredTo: [...message.deliveredTo], readBy: [...message.readBy] }));
}

export function markDelivered({ conversationId, seq, userId }) {
  const conversation = requireConversation(conversationId);
  requireParticipant(conversation, userId);
  const message = findMessage(conversation, seq);
  if (!message.deliveredTo.includes(userId)) message.deliveredTo.push(userId);
  return { ...message, deliveredTo: [...message.deliveredTo], readBy: [...message.readBy] };
}

export function markRead({ conversationId, seq, userId }) {
  const conversation = requireConversation(conversationId);
  requireParticipant(conversation, userId);
  const message = findMessage(conversation, seq);
  if (!message.deliveredTo.includes(userId)) message.deliveredTo.push(userId);
  if (!message.readBy.includes(userId)) message.readBy.push(userId);
  return { ...message, deliveredTo: [...message.deliveredTo], readBy: [...message.readBy] };
}

export function unreadCount({ conversationId, userId }) {
  const conversation = requireConversation(conversationId);
  requireParticipant(conversation, userId);
  return conversation.messages.filter(
    (message) => message.senderId !== userId && !message.readBy.includes(userId),
  ).length;
}

export function setPresence({ conversationId, userId, online, lastSeen }) {
  const conversation = requireConversation(conversationId);
  requireParticipant(conversation, userId);
  if (typeof online !== "boolean") fail("invalid_presence");
  if (!Number.isFinite(lastSeen)) fail("invalid_presence");
  conversation.presence.set(userId, { online, lastSeen });
  return { userId, online, lastSeen };
}

export function getPresence({ conversationId, userId, now }) {
  const conversation = requireConversation(conversationId);
  requireParticipant(conversation, userId);
  if (!Number.isFinite(now)) fail("invalid_now");
  const presence = conversation.presence.get(userId);
  if (!presence || !presence.online) return "offline";
  return now - presence.lastSeen < 60000 ? "online" : "offline";
}
