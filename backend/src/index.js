'use strict';

require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check
app.get('/api/v1/health', (_req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// 404 fallback
app.use((_req, res) => {
  res.status(404).json({ error: 'Endpoint tidak ditemukan.' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Droptix API berjalan di port ${PORT}`);
  });
}

module.exports = app;

