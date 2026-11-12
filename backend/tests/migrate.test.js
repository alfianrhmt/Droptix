'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { buildPoolConfig, withTransaction } = require('../src/db/pool');
const { runMigrations } = require('../db/migrate');

describe('Database pool & migrasi T1.1', () => {
  describe('buildPoolConfig', () => {
    it('memakai DB_* dari environment dan nilai default', () => {
      const cfg = buildPoolConfig({
        DB_HOST: 'db',
        DB_PORT: '5433',
        DB_NAME: 'droptix_test',
        DB_USER: 'tester',
        DB_PASSWORD: 'secret',
      });
      expect(cfg.host).toBe('db');
      expect(cfg.port).toBe(5433);
      expect(cfg.database).toBe('droptix_test');
      expect(cfg.user).toBe('tester');
      expect(cfg.password).toBe('secret');
    });

    it('memprioritaskan DATABASE_URL jika tersedia', () => {
      const cfg = buildPoolConfig({
        DATABASE_URL: 'postgres://user:pass@host:5432/droptix',
      });
      expect(cfg.connectionString).toBe(
        'postgres://user:pass@host:5432/droptix'
      );
      expect(cfg.host).toBeUndefined();
    });
  });

  describe('withTransaction', () => {
    it('melakukan COMMIT dan release client saat sukses', async () => {
      const queries = [];
      let released = false;
      const fakePool = {
        connect: async () => ({
          query: async (sql) => queries.push(sql),
          release: () => {
            released = true;
          },
        }),
      };

      const result = await withTransaction(async (client) => {
        await client.query('SELECT 1');
        return 42;
      }, fakePool);

      expect(result).toBe(42);
      expect(queries).toEqual(['BEGIN', 'SELECT 1', 'COMMIT']);
      expect(released).toBe(true);
    });

    it('melakukan ROLLBACK dan release client saat error', async () => {
      const queries = [];
      let released = false;
      const fakePool = {
        connect: async () => ({
          query: async (sql) => queries.push(sql),
          release: () => {
            released = true;
          },
        }),
      };

      await expect(
        withTransaction(async () => {
          throw new Error('boom');
        }, fakePool)
      ).rejects.toThrow('boom');

      expect(queries).toEqual(['BEGIN', 'ROLLBACK']);
      expect(released).toBe(true);
    });
  });

  describe('001_init.sql', () => {
    const sqlPath = path.join(
      __dirname,
      '../db/migrations/001_init.sql'
    );
    const sql = fs.readFileSync(sqlPath, 'utf8');

    it('mendefinisikan ekstensi pg_trgm dan seluruh tabel dari DATABASE.md', () => {
      expect(sql).toContain('CREATE EXTENSION IF NOT EXISTS pg_trgm');
      const expectedTables = [
        'users',
        'categories',
        'venues',
        'events',
        'listings',
        'listing_photos',
        'favorites',
        'conversations',
        'messages',
        'blocks',
        'reports',
      ];
      for (const table of expectedTables) {
        expect(sql).toMatch(new RegExp(`CREATE TABLE ${table}\\s*\\(`));
      }
    });

    it('memuat indeks penting dan constraint bisnis', () => {
      expect(sql).toContain('idx_venues_nama_trgm');
      expect(sql).toContain('idx_events_nama_trgm');
      expect(sql).toContain('idx_listings_created');
      expect(sql).toContain('UNIQUE (listing_id, buyer_id)');
      expect(sql).toContain('CHECK (buyer_id <> seller_id)');
      expect(sql).toContain('CHECK (jumlah_terjual <= jumlah_total)');
    });
  });

  describe('runMigrations', () => {
    it('menjalankan migrasi baru secara urut dan melewatkan yang sudah diterapkan', async () => {
      const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'droptix-mig-'));
      fs.writeFileSync(path.join(tmpDir, '001_a.sql'), 'CREATE TABLE a();');
      fs.writeFileSync(path.join(tmpDir, '002_b.sql'), 'CREATE TABLE b();');
      fs.writeFileSync(path.join(tmpDir, 'notes.txt'), 'abaikan');

      const executed = [];
      const applied = new Set(['001_a.sql']);

      const fakePool = {
        query: async (text) => {
          if (text.includes('SELECT filename FROM schema_migrations')) {
            return {
              rows: Array.from(applied).map((filename) => ({ filename })),
            };
          }
          return { rows: [] };
        },
        connect: async () => ({
          query: async (text, params) => {
            executed.push({ text, params });
            if (text.startsWith('INSERT INTO schema_migrations')) {
              applied.add(params[0]);
            }
            return { rows: [] };
          },
          release: () => {},
        }),
      };

      const silentLogger = { log: () => {} };
      const firstRun = await runMigrations({
        targetPool: fakePool,
        migrationsDir: tmpDir,
        logger: silentLogger,
      });

      expect(firstRun.applied).toEqual(['002_b.sql']);
      expect(firstRun.skipped).toEqual(['001_a.sql']);
      expect(executed.map((q) => q.text)).toEqual([
        'BEGIN',
        'CREATE TABLE b();',
        'INSERT INTO schema_migrations (filename) VALUES ($1)',
        'COMMIT',
      ]);

      const secondRun = await runMigrations({
        targetPool: fakePool,
        migrationsDir: tmpDir,
        logger: silentLogger,
      });
      expect(secondRun.applied).toEqual([]);
      expect(secondRun.skipped).toEqual(['001_a.sql', '002_b.sql']);

      fs.rmSync(tmpDir, { recursive: true, force: true });
    });
  });
});

