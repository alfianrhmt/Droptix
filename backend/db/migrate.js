'use strict';

const fs = require('fs');
const path = require('path');
const { pool, withTransaction } = require('../src/db/pool');

const DEFAULT_MIGRATIONS_DIR = path.join(__dirname, 'migrations');

/**
 * Menjalankan semua file migrasi .sql yang belum tercatat di schema_migrations.
 * Bersifat idempoten dan tiap file dijalankan dalam satu transaksi.
 */
async function runMigrations({
  targetPool = pool,
  migrationsDir = DEFAULT_MIGRATIONS_DIR,
  logger = console,
} = {}) {
  await targetPool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  const files = fs
    .readdirSync(migrationsDir)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  const { rows: appliedRows } = await targetPool.query(
    'SELECT filename FROM schema_migrations'
  );
  const appliedSet = new Set(appliedRows.map((row) => row.filename));

  const newlyApplied = [];
  const skipped = [];

  for (const filename of files) {
    if (appliedSet.has(filename)) {
      skipped.push(filename);
      continue;
    }

    const sql = fs.readFileSync(path.join(migrationsDir, filename), 'utf8');
    await withTransaction(async (client) => {
      await client.query(sql);
      await client.query(
        'INSERT INTO schema_migrations (filename) VALUES ($1)',
        [filename]
      );
    }, targetPool);

    logger.log(`[migrate] Applied: ${filename}`);
    newlyApplied.push(filename);
  }

  if (newlyApplied.length === 0) {
    logger.log('[migrate] Tidak ada migrasi baru.');
  }

  return { applied: newlyApplied, skipped };
}

if (require.main === module) {
  runMigrations()
    .then(async () => {
      await pool.end();
      process.exit(0);
    })
    .catch(async (err) => {
      console.error('[migrate] Gagal menjalankan migrasi:', err.message);
      await pool.end();
      process.exit(1);
    });
}

module.exports = { runMigrations, DEFAULT_MIGRATIONS_DIR };

