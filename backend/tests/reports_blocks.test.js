'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/index');
const { getJwtSecret } = require('../src/middleware/auth');

function makeToken(user) {
  return jwt.sign({ sub: user.id, email: user.email }, getJwtSecret(), {
    expiresIn: '1h',
  });
}

function createMockDb() {
  const users = [
    { id: 1, nama: 'User Satu', email: 'user1@example.com', banned_at: null },
    { id: 2, nama: 'User Dua', email: 'user2@example.com', banned_at: null },
    { id: 3, nama: 'User Tiga', email: 'user3@example.com', banned_at: null },
  ];

  const events = [
    { id: 10, nama: 'Konser Sheila on 7' },
  ];

  const listings = [
    {
      id: 100,
      seller_id: 2,
      event_id: 10,
      harga: 350000,
      jumlah_total: 2,
      jumlah_terjual: 0,
      waktu_acara: new Date(Date.now() + 86400000).toISOString(),
      deleted_at: null,
      hidden: false,
    },
  ];

  let nextReportId = 1;
  const reports = [];
  const blocks = [];
  const conversations = [];
  const messages = [];

  return {
    users,
    events,
    listings,
    reports,
    blocks,
    conversations,
    messages,
    query: async (sql, params = []) => {
      const q = sql.trim();

      // Auth middleware lookup
      if (q.includes('FROM users') && q.includes('WHERE id = $1')) {
        const u = users.find((x) => x.id === params[0]);
        return { rows: u ? [u] : [] };
      }

      // Check daily report limit
      if (q.includes('SELECT count(*)::int AS total') && q.includes('FROM reports') && q.includes('reporter_id = $1')) {
        const reporterId = params[0];
        const count = reports.filter((r) => r.reporter_id === reporterId).length;
        return { rows: [{ total: count }] };
      }

      // Target existence check for listing
      if (q.includes('SELECT id FROM listings WHERE id = $1')) {
        const l = listings.find((x) => x.id === params[0]);
        return { rows: l ? [{ id: l.id }] : [] };
      }

      // Target existence check for event
      if (q.includes('SELECT id FROM events WHERE id = $1')) {
        const e = events.find((x) => x.id === params[0]);
        return { rows: e ? [{ id: e.id }] : [] };
      }

      // Insert report
      if (q.includes('INSERT INTO reports')) {
        const rep = {
          id: nextReportId++,
          reporter_id: params[0],
          target_type: params[1],
          target_id: params[2],
          alasan: params[3],
          keterangan: params[4],
          status: 'baru',
          created_at: new Date().toISOString(),
        };
        reports.push(rep);
        return { rows: [{ id: rep.id }] };
      }

      // Insert block
      if (q.includes('INSERT INTO blocks')) {
        const blockerId = params[0];
        const blockedId = params[1];
        const exists = blocks.some(
          (b) => b.blocker_id === blockerId && b.blocked_id === blockedId
        );
        if (!exists) {
          blocks.push({
            blocker_id: blockerId,
            blocked_id: blockedId,
            created_at: new Date().toISOString(),
          });
        }
        return { rowCount: 1 };
      }

      // Delete block
      if (q.includes('DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2')) {
        const blockerId = params[0];
        const blockedId = params[1];
        const idx = blocks.findIndex(
          (b) => b.blocker_id === blockerId && b.blocked_id === blockedId
        );
        if (idx !== -1) {
          blocks.splice(idx, 1);
        }
        return { rowCount: 1 };
      }

      // List my blocks
      if (q.includes('FROM blocks b') && q.includes('JOIN users u ON u.id = b.blocked_id') && q.includes('WHERE b.blocker_id = $1')) {
        const blockerId = params[0];
        const list = blocks
          .filter((b) => b.blocker_id === blockerId)
          .map((b) => {
            const u = users.find((x) => x.id === b.blocked_id);
            return {
              id: b.blocked_id,
              nama: u ? u.nama : 'Unknown',
            };
          });
        return { rows: list };
      }

      // Block check (checkBlockBetween)
      if (q.includes('FROM blocks') && q.includes('WHERE (blocker_id = $1 AND blocked_id = $2)')) {
        const found = blocks.some(
          (b) =>
            (b.blocker_id === params[0] && b.blocked_id === params[1]) ||
            (b.blocker_id === params[1] && b.blocked_id === params[0])
        );
        return { rows: found ? [{ 1: 1 }] : [] };
      }

      // Count unread chats in me.js
      if (q.includes('SELECT count(*)::int AS chats FROM conversations c')) {
        return { rows: [{ chats: 0 }] };
      }

      // Fallback
      return { rows: [] };
    },
  };
}

describe('T7.1: Backend Reports and Blocks Endpoints', () => {
  let db;
  let app;
  let user1Token;
  let user2Token;

  beforeEach(() => {
    db = createMockDb();
    app = createApp({ db, useRateLimit: false });
    user1Token = makeToken(db.users[0]);
    user2Token = makeToken(db.users[1]);
  });

  describe('POST /api/v1/reports', () => {
    it('menolak tanpa token autentikasi (401)', async () => {
      const res = await request(app)
        .post('/api/v1/reports')
        .send({
          target_type: 'listing',
          target_id: 100,
          alasan: 'penipuan',
        });
      expect(res.status).toBe(401);
    });

    it('menolak body tidak valid (422)', async () => {
      const res = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'invalid_type',
          target_id: 'bukan_angka',
          alasan: 'alasan_palsu',
        });
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('menolak jika pengguna mencoba melaporkan akun sendiri (422)', async () => {
      const res = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'user',
          target_id: 1, // User 1 lapor diri sendiri
          alasan: 'spam',
        });
      expect(res.status).toBe(422);
      expect(res.body.error.details[0].message).toContain('Tidak dapat melaporkan akun sendiri');
    });

    it('menolak jika target tidak ditemukan (404)', async () => {
      const resListing = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'listing',
          target_id: 9999,
          alasan: 'tiket_palsu',
        });
      expect(resListing.status).toBe(404);

      const resEvent = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'event',
          target_id: 9999,
          alasan: 'spam',
        });
      expect(resEvent.status).toBe(404);

      const resUser = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'user',
          target_id: 9999,
          alasan: 'penipuan',
        });
      expect(resUser.status).toBe(404);
    });

    it('berhasil membuat laporan untuk listing (201)', async () => {
      const res = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'listing',
          target_id: 100,
          alasan: 'penipuan',
          keterangan: 'Harga tidak wajar dan indikasi penipuan',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toHaveProperty('id');
      expect(db.reports.length).toBe(1);
      expect(db.reports[0].target_type).toBe('listing');
      expect(db.reports[0].target_id).toBe(100);
      expect(db.reports[0].status).toBe('baru');
    });

    it('berhasil membuat laporan untuk user dan event (201)', async () => {
      const resUser = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'user',
          target_id: 2,
          alasan: 'tidak_pantas',
        });
      expect(resUser.status).toBe(201);

      const resEvent = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'event',
          target_id: 10,
          alasan: 'lainnya',
          keterangan: 'Nama event duplikat',
        });
      expect(resEvent.status).toBe(201);
    });

    it('menolak pengiriman laporan melebihi batas 10 per hari (429 RATE_LIMITED)', async () => {
      // Buat 10 laporan
      for (let i = 0; i < 10; i++) {
        db.reports.push({
          id: i + 1,
          reporter_id: 1,
          target_type: 'listing',
          target_id: 100,
          alasan: 'spam',
          created_at: new Date().toISOString(),
        });
      }

      // Laporan ke-11 harus ditolak 429
      const res = await request(app)
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          target_type: 'listing',
          target_id: 100,
          alasan: 'spam',
        });

      expect(res.status).toBe(429);
      expect(res.body.error.code).toBe('RATE_LIMITED');
      expect(res.body.error.message).toContain('10 laporan per hari');
    });
  });

  describe('POST & DELETE /api/v1/users/:id/block', () => {
    it('menolak memblokir diri sendiri (422)', async () => {
      const res = await request(app)
        .post('/api/v1/users/1/block')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(res.status).toBe(422);
      expect(res.body.error.details[0].message).toContain('Tidak dapat memblokir akun sendiri');
    });

    it('menolak jika target user tidak ditemukan (404)', async () => {
      const res = await request(app)
        .post('/api/v1/users/999/block')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(res.status).toBe(404);
    });

    it('berhasil memblokir pengguna secara idempoten (200)', async () => {
      // Blokir pertama
      const res1 = await request(app)
        .post('/api/v1/users/2/block')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(res1.status).toBe(200);
      expect(res1.body.data).toEqual({ blocked: true });
      expect(db.blocks.length).toBe(1);

      // Blokir kedua (idempoten)
      const res2 = await request(app)
        .post('/api/v1/users/2/block')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(res2.status).toBe(200);
      expect(res2.body.data).toEqual({ blocked: true });
      expect(db.blocks.length).toBe(1);
    });

    it('berhasil membuka blokir pengguna secara idempoten (200)', async () => {
      // Pasang blokir awal
      db.blocks.push({ blocker_id: 1, blocked_id: 2 });

      const resDel = await request(app)
        .delete('/api/v1/users/2/block')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(resDel.status).toBe(200);
      expect(resDel.body.data).toEqual({ blocked: false });
      expect(db.blocks.length).toBe(0);

      // Unblock lagi (idempoten)
      const resDel2 = await request(app)
        .delete('/api/v1/users/2/block')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(resDel2.status).toBe(200);
      expect(resDel2.body.data).toEqual({ blocked: false });
    });
  });

  describe('GET /api/v1/me/blocks', () => {
    it('mengembalikan daftar pengguna yang diblokir oleh pengguna aktif', async () => {
      db.blocks.push({ blocker_id: 1, blocked_id: 2 });

      const res = await request(app)
        .get('/api/v1/me/blocks')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0]).toEqual({
        id: 2,
        nama: 'User Dua',
      });
    });

    it('daftar berkurang saat blokir dicabut', async () => {
      db.blocks.push({ blocker_id: 1, blocked_id: 2 });

      // Unblock
      await request(app)
        .delete('/api/v1/users/2/block')
        .set('Authorization', `Bearer ${user1Token}`);

      const res = await request(app)
        .get('/api/v1/me/blocks')
        .set('Authorization', `Bearer ${user1Token}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([]);
    });
  });

  describe('Integrasi Pemblokiran dengan Aturan BR-12', () => {
    it('memblokir pengguna mengaktifkan status pemblokiran dua arah dan memulihkannya saat unblock', async () => {
      // Belum diblokir
      const checkSql =
        'SELECT 1 FROM blocks WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)';
      let resCheck = await db.query(checkSql, [1, 2]);
      expect(resCheck.rows.length).toBe(0);

      // User 1 memblokir User 2
      await request(app)
        .post('/api/v1/users/2/block')
        .set('Authorization', `Bearer ${user1Token}`);

      // Cek pemblokiran terdeteksi dari sudut pandang User 1 maupun User 2
      let resBlocked1 = await db.query(checkSql, [1, 2]);
      expect(resBlocked1.rows.length).toBe(1);

      let resBlocked2 = await db.query(checkSql, [2, 1]);
      expect(resBlocked2.rows.length).toBe(1);

      // User 1 membuka blokir
      await request(app)
        .delete('/api/v1/users/2/block')
        .set('Authorization', `Bearer ${user1Token}`);

      let resUnblocked = await db.query(checkSql, [1, 2]);
      expect(resUnblocked.rows.length).toBe(0);
    });
  });
});
