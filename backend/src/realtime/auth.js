'use strict';

const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../middleware/auth');

/**
 * Middleware autentikasi Socket.IO menggunakan JWT token.
 * Sesuai API.md bagian 10:
 * - Klien menyambung dengan auth: { token: <jwt> }
 * - Token tidak valid atau akun dibekukan -> connect_error
 */
function createSocketAuthMiddleware(db) {
  return async (socket, next) => {
    try {
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.headers?.authorization?.replace(/^Bearer\s+/i, '');

      if (!token) {
        const err = new Error('Token autentikasi diperlukan.');
        err.data = { code: 'UNAUTHORIZED' };
        return next(err);
      }

      let decoded;
      try {
        decoded = jwt.verify(token, getJwtSecret());
      } catch {
        const err = new Error('Token tidak valid atau kedaluwarsa.');
        err.data = { code: 'UNAUTHORIZED' };
        return next(err);
      }

      const userId = decoded.sub;
      const { rows } = await db.query(
        'SELECT id, nama, email, banned_at FROM users WHERE id = $1 LIMIT 1',
        [userId]
      );
      const user = rows[0];

      if (!user) {
        const err = new Error('Pengguna tidak ditemukan.');
        err.data = { code: 'UNAUTHORIZED' };
        return next(err);
      }

      if (user.banned_at) {
        const err = new Error('Akun telah dibekukan.');
        err.data = { code: 'FORBIDDEN' };
        return next(err);
      }

      socket.user = user;
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

module.exports = {
  createSocketAuthMiddleware,
};
