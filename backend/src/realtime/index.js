'use strict';

const { Server: SocketIOServer } = require('socket.io');
const { createSocketAuthMiddleware } = require('./auth');
const { emitMessageNew, emitUnreadUpdate } = require('./events');

/**
 * Menginisialisasi Socket.IO pada server HTTP yang diberikan.
 * - Memasang middleware autentikasi JWT
 * - Memasukkan socket yang berhasil autentikasi ke room `user:{id}`
 */
function initSocketIO(server, { db }) {
  const io = new SocketIOServer(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  io.use(createSocketAuthMiddleware(db));

  io.on('connection', (socket) => {
    const user = socket.user;
    if (user) {
      // Room per pengguna: user:{id}
      socket.join(`user:${user.id}`);
    }
  });

  return io;
}

module.exports = {
  initSocketIO,
  emitMessageNew,
  emitUnreadUpdate,
};
