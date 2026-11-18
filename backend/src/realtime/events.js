'use strict';

/**
 * Mengirim event `message:new` dan (opsional) `unread:update` ke lawan bicara.
 * Format sesuai API.md bagian 10:
 * - message:new: { "message": Message, "conversation": { "id", "belum_dibaca" } }
 * - unread:update: { "chats": count }
 */
function emitMessageNew(io, {
  lawanId,
  message,
  conversationId,
  belumDibacaLawan,
  unreadChatsLawan,
}) {
  if (!io) return;

  io.to(`user:${lawanId}`).emit('message:new', {
    message,
    conversation: {
      id: Number(conversationId),
      belum_dibaca: Number(belumDibacaLawan || 0),
    },
  });

  if (typeof unreadChatsLawan === 'number') {
    io.to(`user:${lawanId}`).emit('unread:update', {
      chats: unreadChatsLawan,
    });
  }
}

/**
 * Mengirim event `unread:update` ke pengguna saat jumlah percakapan belum dibaca berubah.
 * Format sesuai API.md bagian 10:
 * - unread:update: { "chats": count }
 */
function emitUnreadUpdate(io, { userId, chats }) {
  if (!io) return;

  io.to(`user:${userId}`).emit('unread:update', {
    chats: Number(chats || 0),
  });
}

module.exports = {
  emitMessageNew,
  emitUnreadUpdate,
};
