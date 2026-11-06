const conversations = new Map();

export function reset() {
  conversations.clear();
}

export function createConversation({ id, participants }) {
  const conversation = { id, participants, messages: [], nextSeq: 1 };
  conversations.set(id, conversation);
  return { id, participants };
}

export function sendMessage({ conversationId, senderId, text }) {
  const conversation = conversations.get(conversationId);
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
  return { ...message };
}

export function listMessages({ conversationId, afterSeq = 0 }) {
  return conversations.get(conversationId).messages.filter((message) => message.seq > afterSeq);
}

export function markDelivered({ conversationId, seq, userId }) {
  const message = conversations.get(conversationId).messages.find((item) => item.seq === seq);
  if (!message.deliveredTo.includes(userId)) message.deliveredTo.push(userId);
  return { ...message };
}

export function markRead({ conversationId, seq, userId }) {
  return markDelivered({ conversationId, seq, userId });
}

export function unreadCount({ conversationId, userId }) {
  return listMessages({ conversationId }).filter((message) => !message.readBy.includes(userId)).length;
}
