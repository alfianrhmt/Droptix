'use strict';

require('dotenv').config();
const http = require('http');
const path = require('path');
const express = require('express');
const cors = require('cors');
const defaultPool = require('./db/pool');
const { errorHandler, Errors } = require('./utils/errors');
const { generalLimiter, authLimiter } = require('./middleware/rateLimit');
const { createRequireAuth, createOptionalAuth } = require('./middleware/auth');
const { createAuthRouter } = require('./routes/auth');
const { createMeRouter } = require('./routes/me');
const { createCategoriesRouter } = require('./routes/categories');
const { createVenuesRouter } = require('./routes/venues');
const { createEventsRouter } = require('./routes/events');
const { createUploadsRouter } = require('./routes/uploads');
const { createListingsRouter } = require('./routes/listings');
const { createConversationsRouter } = require('./routes/conversations');
const { createReportsRouter } = require('./routes/reports');
const { createUsersRouter } = require('./routes/users');
const { createBannersRouter } = require('./routes/banners');
const { initSocketIO } = require('./realtime');

const DEFAULT_UPLOADS_DIR = path.resolve(__dirname, '../uploads');

function createApp({
  db = defaultPool,
  useRateLimit = true,
  uploadsDir = DEFAULT_UPLOADS_DIR,
  io,
} = {}) {
  const app = express();
  const server = http.createServer(app);
  const socketIo = io !== undefined ? io : initSocketIO(server, { db });
  if (socketIo) {
    app.set('io', socketIo);
  }
  app.server = server;
  app.io = socketIo;

  const requireAuth = createRequireAuth(db);
  const optionalAuth = createOptionalAuth(db);

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
  app.use('/api/v1/events', createEventsRouter(db, requireAuth, optionalAuth));
  app.use('/api/v1/uploads', createUploadsRouter(requireAuth, uploadsDir));
  app.use(
    '/api/v1/listings',
    createListingsRouter(db, requireAuth, optionalAuth, useRateLimit)
  );
  app.use(
    '/api/v1/conversations',
    createConversationsRouter(db, requireAuth, useRateLimit)
  );
  app.use('/api/v1/reports', createReportsRouter(db, requireAuth));
  app.use('/api/v1/users', createUsersRouter(db, requireAuth));
  app.use('/api/v1/banners', createBannersRouter(db));

  // 404 fallback seragam
  app.use((_req, _res, next) => {
    next(Errors.notFound('Endpoint tidak ditemukan.'));
  });

  // Error handler seragam
  app.use(errorHandler);

  return app;
}

function createServer(options = {}) {
  const app = createApp(options);
  return {
    app,
    server: app.server,
    io: app.io,
  };
}

const app = createApp();
const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.server.listen(PORT, () => {
    console.log(`Droptix API berjalan di port ${PORT}`);
  });
}

app.createApp = createApp;
app.createServer = createServer;
module.exports = app;
module.exports.createApp = createApp;
module.exports.createServer = createServer;
