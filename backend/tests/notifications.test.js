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

describe('Notifications Endpoints', () => {
  const user1 = { id: 1, nama: 'Alfian', email: 'alfian@example.com', banned_at: null };
  const token = makeToken(user1);
  let notifications;
  let app;

  beforeEach(() => {
    notifications = [
      {
        id: 10,
        user_id: 1,
        type: 'new_ticket',
        title: 'Tiket Baru Tersedia',
        body: 'Avengers Doomsday · 2 tiket Rp 25.000 di XXI Tunjungan Plaza',
        event_id: 14,
        event_nama: 'Avengers Doomsday',
        event_poster_url: '/uploads/avengers.jpg',
        listing_id: 18,
        is_read: false,
        created_at: new Date().toISOString(),
      },
    ];

    const mockDb = {
      query: jest.fn(async (sql, params = []) => {
        if (sql.includes('FROM users') && sql.includes('WHERE id = $1')) {
          return { rows: [user1] };
        }
        if (sql.includes('FROM notifications n') && sql.includes('WHERE n.user_id = $1')) {
          return { rows: notifications.filter((n) => n.user_id === Number(params[0])) };
        }
        if (sql.includes('COUNT(*)::int AS unread_count') && sql.includes('FROM notifications')) {
          const unread = notifications.filter(
            (n) => n.user_id === Number(params[0]) && !n.is_read
          ).length;
          return { rows: [{ unread_count: unread }] };
        }
        if (sql.includes('UPDATE notifications') && sql.includes('WHERE id = $1 AND user_id = $2')) {
          const found = notifications.find(
            (n) => n.id === Number(params[0]) && n.user_id === Number(params[1])
          );
          if (!found) return { rows: [] };
          found.is_read = true;
          return { rows: [{ id: found.id, is_read: true }] };
        }
        if (sql.includes('UPDATE notifications') && sql.includes('WHERE user_id = $1 AND is_read = false')) {
          for (const n of notifications) {
            if (n.user_id === Number(params[0])) n.is_read = true;
          }
          return { rows: [] };
        }
        return { rows: [] };
      }),
    };

    app = createApp({ db: mockDb, useRateLimit: false });
  });

  it('GET /api/v1/notifications menolak tamu dengan 401', async () => {
    const res = await request(app).get('/api/v1/notifications');
    expect(res.status).toBe(401);
  });

  it('GET /api/v1/notifications mengembalikan daftar notifikasi & meta unread_count', async () => {
    const res = await request(app)
      .get('/api/v1/notifications')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].title).toBe('Tiket Baru Tersedia');
    expect(res.body.meta.unread_count).toBe(1);
  });

  it('GET /api/v1/notifications/unread-count mengembalikan jumlah belum dibaca', async () => {
    const res = await request(app)
      .get('/api/v1/notifications/unread-count')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data.unread_count).toBe(1);
  });

  it('PATCH /api/v1/notifications/:id/read menandai 1 notifikasi sebagai dibaca', async () => {
    const res = await request(app)
      .patch('/api/v1/notifications/10/read')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data.is_read).toBe(true);

    const countRes = await request(app)
      .get('/api/v1/notifications/unread-count')
      .set('Authorization', `Bearer ${token}`);
    expect(countRes.body.data.unread_count).toBe(0);
  });

  it('POST /api/v1/notifications/read-all menandai semua notifikasi sebagai dibaca', async () => {
    const res = await request(app)
      .post('/api/v1/notifications/read-all')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data.unread_count).toBe(0);
  });
});
