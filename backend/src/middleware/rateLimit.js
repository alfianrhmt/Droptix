'use strict';

const rateLimit = require('express-rate-limit');

function createLimiter({ windowMs, max, message }) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        error: {
          code: 'RATE_LIMITED',
          message,
        },
      });
    },
  });
}

// 100 request/menit/IP secara umum (API.md bagian 1)
const generalLimiter = createLimiter({
  windowMs: 60 * 1000,
  max: 100,
  message: 'Terlalu banyak permintaan. Coba lagi sebentar.',
});

// 10 request/menit/IP untuk /auth/* (API.md bagian 1)
const authLimiter = createLimiter({
  windowMs: 60 * 1000,
  max: 10,
  message: 'Terlalu banyak percobaan autentikasi. Coba lagi dalam 1 menit.',
});

module.exports = { createLimiter, generalLimiter, authLimiter };

