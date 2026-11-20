'use strict';

const jwt = require('jsonwebtoken');
const { Errors } = require('../utils/errors');

function getJwtSecret() {
  if (process.env.JWT_SECRET) return process.env.JWT_SECRET;
  if (process.env.NODE_ENV === 'production') {
    throw new Error('JWT_SECRET wajib diisi di production.');
  }
  return 'droptix-dev-jwt-secret';
}

function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email },
    getJwtSecret(),
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

function verifyToken(token) {
  return jwt.verify(token, getJwtSecret());
}

/**
 * Middleware autentikasi JWT. Memeriksa header Bearer token dan status akun.
 */
function createRequireAuth(db) {
  return async (req, _res, next) => {
    try {
      const header = req.headers.authorization || '';
      if (!header.startsWith('Bearer ')) {
        return next(Errors.unauthorized('Token autentikasi tidak ditemukan.'));
      }

      const token = header.slice(7).trim();
      if (!token) {
        return next(Errors.unauthorized('Token autentikasi tidak valid.'));
      }

      let payload;
      try {
        payload = verifyToken(token);
      } catch (_err) {
        return next(
          Errors.unauthorized('Sesi tidak valid atau sudah kedaluwarsa.')
        );
      }

      const { rows } = await db.query(
        `SELECT id, username, nama, email, no_wa, kota, foto_url, banned_at, created_at
         FROM users
         WHERE id = $1
         LIMIT 1`,
        [payload.sub]
      );

      if (rows.length === 0) {
        return next(Errors.unauthorized('Pengguna tidak ditemukan.'));
      }

      const user = rows[0];
      if (user.banned_at) {
        return next(Errors.accountBanned());
      }

      req.user = {
        id: user.id,
        username: user.username,
        nama: user.nama,
        email: user.email,
        no_wa: user.no_wa,
        kota: user.kota,
        foto_url: user.foto_url || null,
        created_at: user.created_at,
      };
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

/**
 * Middleware autentikasi opsional: mengisi req.user bila Bearer token valid dan akun aktif,
 * namun tetap melanjutkan sebagai tamu bila tanpa token atau token tidak valid.
 */
function createOptionalAuth(db) {
  return async (req, _res, next) => {
    try {
      const header = req.headers.authorization || '';
      if (!header.startsWith('Bearer ')) {
        req.user = null;
        return next();
      }

      const token = header.slice(7).trim();
      if (!token) {
        req.user = null;
        return next();
      }

      let payload;
      try {
        payload = verifyToken(token);
      } catch (_err) {
        req.user = null;
        return next();
      }

      const { rows } = await db.query(
        `SELECT id, username, nama, email, no_wa, kota, foto_url, banned_at, created_at
         FROM users
         WHERE id = $1
         LIMIT 1`,
        [payload.sub]
      );

      if (rows.length === 0 || rows[0].banned_at) {
        req.user = null;
        return next();
      }

      const user = rows[0];
      req.user = {
        id: user.id,
        username: user.username,
        nama: user.nama,
        email: user.email,
        no_wa: user.no_wa,
        kota: user.kota,
        foto_url: user.foto_url || null,
        created_at: user.created_at,
      };
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

module.exports = {
  signToken,
  verifyToken,
  createRequireAuth,
  createOptionalAuth,
  getJwtSecret,
};

