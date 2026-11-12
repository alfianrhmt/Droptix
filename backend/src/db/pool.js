'use strict';

const path = require('path');
const dotenv = require('dotenv');
const { Pool } = require('pg');

// Muat .env dari root repo jika belum dimuat dari cwd backend/
dotenv.config();
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

/**
 * Membangun konfigurasi pool PostgreSQL dari environment variables.
 */
function buildPoolConfig(env = process.env) {
  if (env.DATABASE_URL) {
    return {
      connectionString: env.DATABASE_URL,
      max: Number(env.DB_POOL_MAX) || 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    };
  }

  return {
    host: env.DB_HOST || 'localhost',
    port: Number(env.DB_PORT) || 5432,
    database: env.DB_NAME || 'droptix',
    user: env.DB_USER || 'droptix_user',
    password: env.DB_PASSWORD || 'changeme',
    max: Number(env.DB_POOL_MAX) || 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
  };
}

const pool = new Pool(buildPoolConfig());

/**
 * Menjalankan satu query menggunakan pool bersama.
 */
function query(text, params) {
  return pool.query(text, params);
}

/**
 * Menjalankan fungsi callback di dalam transaksi PostgreSQL (BEGIN/COMMIT/ROLLBACK).
 */
async function withTransaction(fn, targetPool = pool) {
  const client = await targetPool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  query,
  withTransaction,
  buildPoolConfig,
};

