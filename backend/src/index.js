'use strict';

require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const defaultPool = require('./db/pool');
const { errorHandler, Errors } = require('./utils/errors');
const { generalLimiter, authLimiter } = require('./middleware/rateLimit');
const { createRequireAuth } = require('./middleware/auth');
const { createAuthRouter } = require('./routes/auth');
const { createMeRouter } = require('./routes/me');
const { createCategoriesRouter } = require('./routes/categories');
const { createVenuesRouter } = require('./routes/venues');
const { createEventsRouter } = require('./routes/events');
const { createUploadsRouter } = require('./routes/uploads');

const DEFAULT_UPLOADS_DIR = path.resolve(__dirname, '../uploads');

function createApp({
  db = defaultPool,
  useRateLimit = true,
  uploadsDir = DEFAULT_UPLOADS_DIR,
} = {}) {
  const app = express();
  const requireAuth = createRequireAuth(db);

  app.use(cors());
  app.use(express.json());
  app.use('/uploads', express.static(uploadsDir));
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
  app.use('/api/v1/categories', createCategoriesRouter(db));
  app.use('/api/v1/venues', createVenuesRouter(db));
  app.use('/api/v1/events', createEventsRouter(db, requireAuth));
  app.use('/api/v1/uploads', createUploadsRouter(requireAuth, uploadsDir));

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
