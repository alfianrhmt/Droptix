'use strict';

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const defaultPool = require('./db/pool');
const { errorHandler, Errors } = require('./utils/errors');
const { generalLimiter, authLimiter } = require('./middleware/rateLimit');
const { createRequireAuth } = require('./middleware/auth');
const { createAuthRouter } = require('./routes/auth');
const { createMeRouter } = require('./routes/me');

function createApp({ db = defaultPool, useRateLimit = true } = {}) {
  const app = express();
  const requireAuth = createRequireAuth(db);

  app.use(cors());
  app.use(express.json());
  if (useRateLimit) {
    app.use('/api/v1', generalLimiter);
  }

  // Health check
  app.get('/api/v1/health', (_req, res) => {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
    });
  });

  // Auth & Me
  if (useRateLimit) {
    app.use('/api/v1/auth', authLimiter, createAuthRouter(db));
  } else {
    app.use('/api/v1/auth', createAuthRouter(db));
  }
  app.use('/api/v1/me', createMeRouter(db, requireAuth));

  // 404 fallback seragam
  app.use((_req, _res, next) => {
    next(Errors.notFound('Endpoint tidak ditemukan.'));
  });

  // Error handler seragam
  app.use(errorHandler);

  return app;
}

const app = createApp();
const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Droptix API berjalan di port ${PORT}`);
  });
}

app.createApp = createApp;
module.exports = app;
