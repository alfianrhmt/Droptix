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

// 30 pesan/menit per pengguna (API.md bagian 6 & BR-11)
function createChatMessageLimiter() {
  return rateLimit({
    windowMs: 60 * 1000,
    max: 30,
    keyGenerator: (req) => (req.user ? `user:${req.user.id}` : req.ip),
    validate: { keyGeneratorIpFallback: false },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        error: {
          code: 'RATE_LIMITED',
          message: 'Batas 30 pesan per menit tercapai. Silakan tunggu sejenak.',
        },
      });
    },
  });
}

const chatMessageLimiter = createChatMessageLimiter();

module.exports = {
  createLimiter,
  generalLimiter,
  authLimiter,
  chatMessageLimiter,
  createChatMessageLimiter,
};

