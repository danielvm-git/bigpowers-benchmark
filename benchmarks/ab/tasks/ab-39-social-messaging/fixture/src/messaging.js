const users = new Map();
const conversations = new Map();
export function reset() { users.clear(); conversations.clear(); }
export function createUser({ id, private: isPrivate = false }) { const u = { id, private: Boolean(isPrivate), followers: new Set() }; users.set(id, u); return { id, private: u.private }; }
export function follow({ followerId, followeeId }) { const target = users.get(followeeId); target.followers.add(followerId); return { status: "accepted" }; }
export function acceptFollow({ followerId, followeeId }) { users.get(followeeId).followers.add(followerId); return { status: "accepted" }; }
export function startConversation({ id, fromUserId, toUserId }) { const c = { id, participants: new Set([fromUserId, toUserId]), messages: [], nextSeq: 1 }; conversations.set(id, c); return { id, participants: [fromUserId, toUserId] }; }
export function sendMessage({ conversationId, senderId, text }) { const c = conversations.get(conversationId); const m = { seq: c.nextSeq++, senderId, text, deliveredTo: [], readBy: [] }; c.messages.push(m); return { ...m }; }
export function listMessages({ conversationId }) { return conversations.get(conversationId).messages.map((m) => ({ ...m })); }
export function markRead({ conversationId, seq, userId }) { const m = conversations.get(conversationId).messages.find((x) => x.seq === seq); m.readBy.push(userId); return { ...m }; }
export function unreadCount({ conversationId, userId }) { return listMessages({ conversationId }).filter((m) => m.senderId !== userId && !m.readBy.includes(userId)).length; }
