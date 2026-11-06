const users = new Map();
const conversations = new Map();
export function reset() { users.clear(); conversations.clear(); }
function fail(code) { throw new Error(code); }
function requireUser(id) { const u = users.get(id); if (!u) fail(`user_not_found: ${id}`); return u; }
function requireConversation(id) { const c = conversations.get(id); if (!c) fail(`conversation_not_found: ${id}`); return c; }
function requireParticipant(conversation, userId) { if (!conversation.participants.has(userId)) fail(`not_participant: ${userId}`); }

export function createUser({ id, private: isPrivate = false }) {
  if (typeof id !== "string" || !id) fail("invalid_user_id");
  if (users.has(id)) fail(`duplicate_user: ${id}`);
  const user = { id, private: Boolean(isPrivate), followers: new Set(), pending: new Set() };
  users.set(id, user); return { id, private: user.private };
}
export function follow({ followerId, followeeId }) {
  const follower = requireUser(followerId); const target = requireUser(followeeId);
  if (follower.id === target.id) fail("self_follow");
  if (target.followers.has(follower.id)) return { status: "accepted" };
  if (target.pending.has(follower.id)) return { status: "pending" };
  if (target.private) { target.pending.add(follower.id); return { status: "pending" }; }
  target.followers.add(follower.id); return { status: "accepted" };
}
export function acceptFollow({ followerId, followeeId }) {
  const follower = requireUser(followerId); const target = requireUser(followeeId);
  if (!target.pending.has(follower.id)) fail("follow_not_found");
  target.pending.delete(follower.id); target.followers.add(follower.id);
  return { status: "accepted" };
}
export function startConversation({ id, fromUserId, toUserId }) {
  const from = requireUser(fromUserId); const to = requireUser(toUserId);
  if (from.id === to.id) fail("self_conversation");
  if (typeof id !== "string" || !id) fail("invalid_conversation_id");
  if (conversations.has(id)) fail(`duplicate_conversation: ${id}`);
  if (to.private && !to.followers.has(from.id)) fail("not_allowed");
  const conversation = { id, participants: new Set([from.id, to.id]), messages: [], nextSeq: 1, byClientId: new Map() };
  conversations.set(id, conversation);
  return { id, participants: [from.id, to.id] };
}
export function sendMessage({ conversationId, senderId, text, clientId }) {
  const conversation = requireConversation(conversationId); requireParticipant(conversation, senderId);
  if (typeof text !== "string" || !text.trim()) fail("invalid_text");
  if (typeof clientId !== "string" || !clientId.trim()) fail("invalid_client_id");
  if (conversation.byClientId.has(clientId)) return { ...conversation.byClientId.get(clientId) };
  const message = { id: `M-${conversation.nextSeq}`, seq: conversation.nextSeq, senderId, text, deliveredTo: [], readBy: [] };
  conversation.nextSeq += 1;
  conversation.messages.push(message); conversation.byClientId.set(clientId, message);
  return { ...message };
}
export function listMessages({ conversationId, userId, afterSeq = 0 }) {
  const conversation = requireConversation(conversationId); requireParticipant(conversation, userId);
  return conversation.messages.filter((m) => m.seq > afterSeq)
    .map((m) => ({ ...m, deliveredTo: [...m.deliveredTo], readBy: [...m.readBy] }));
}
export function markDelivered({ conversationId, seq, userId }) {
  const conversation = requireConversation(conversationId); requireParticipant(conversation, userId);
  const message = conversation.messages.find((m) => m.seq === seq);
  if (!message) fail(`message_not_found: ${seq}`);
  if (!message.deliveredTo.includes(userId)) message.deliveredTo.push(userId);
  return { ...message, deliveredTo: [...message.deliveredTo], readBy: [...message.readBy] };
}
export function markRead({ conversationId, seq, userId }) {
  const delivered = markDelivered({ conversationId, seq, userId });
  const conversation = requireConversation(conversationId);
  const message = conversation.messages.find((m) => m.seq === seq);
  if (!message.readBy.includes(userId)) message.readBy.push(userId);
  return { ...message, deliveredTo: [...message.deliveredTo], readBy: [...message.readBy] };
}
export function unreadCount({ conversationId, userId }) {
  const conversation = requireConversation(conversationId); requireParticipant(conversation, userId);
  return conversation.messages.filter((m) => m.senderId !== userId && !m.readBy.includes(userId)).length;
}
