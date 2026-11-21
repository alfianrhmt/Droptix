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

describe('Events Detail and Alert Endpoints', () => {
  let app;
  let mockDb;
  const user1 = { id: 1, nama: 'Alfian', email: 'alfian@example.com', banned_at: null };
  const token = makeToken(user1);

  const testEvent = {
    id: 1,
    nama: 'Avengers: Secret Wars',
    nama_normal: 'avengers: secret wars',
    poster_url: '/uploads/avengers.jpg',
    category_id: 2,
    category_slug: 'bioskop',
    category_nama: 'Bioskop',
    category_ikon: 'movie',
    venue_id: null,
    venue_nama: null,
    venue_kota: null,
    venue_alamat: null,
    venue_lat: null,
    venue_lng: null,
    tanggal: null,
    tanggal_opsi: ['2026-12-01', '2026-12-02'],
    created_by: 1,
    hidden: false,
  };

  const testAlerts = new Map(); // key: `${eventId}:${userId}` -> boolean

  beforeEach(() => {
    mockDb = {
      query: jest.fn(async (sql, params = []) => {
        // Auth query: SELECT id, nama, email, no_wa, kota, banned_at FROM users WHERE id = $1
        if (sql.includes('FROM users') && sql.includes('WHERE id = $1')) {
          return { rows: [user1] };
        }

        // fetchEventById
        if (sql.includes('FROM events e') && sql.includes('WHERE e.id = $1')) {
          const id = Number(params[0]);
          if (id === 1) return { rows: [testEvent] };
          return { rows: [] };
        }

        // is_alert_active
        if (sql.includes('FROM event_alerts WHERE event_id = $1 AND user_id = $2')) {
          const key = `${params[0]}:${params[1]}`;
          if (testAlerts.has(key)) {
            return { rows: [{ is_active: testAlerts.get(key) }] };
          }
          return { rows: [] };
        }

        // Stats query
        if (sql.includes('COALESCE(SUM(l.jumlah_total - l.jumlah_terjual), 0)::int AS available_tickets_count')) {
          return {
            rows: [
              {
                available_tickets_count: 5,
                min_price: 50000,
                max_price: 75000,
                sellers_count: 2,
              },
            ],
          };
        }

        // Listings query
        if (sql.includes('FROM listings l') && sql.includes('JOIN events e')) {
          return {
            rows: [
              {
                id: 10,
                event_id: 1,
                event_nama: 'Avengers: Secret Wars',
                event_poster_url: '/uploads/avengers.jpg',
                category_id: 2,
                category_slug: 'bioskop',
                category_nama: 'Bioskop',
                venue_id: 5,
                venue_nama: 'Cinema XXI Tunjungan Plaza',
                venue_teks: null,
                kota: 'Surabaya',
                waktu_acara: new Date(Date.now() + 86400000).toISOString(),
                jenis: 'last_minute',
                tipe: 'digital',
                seksi: 'Studio 1',
                harga: 50000,
                harga_asli: 65000,
                jumlah_total: 2,
                jumlah_terjual: 0,
                tertarik: 3,
                ref_lat: -7.26,
                ref_lng: 112.74,
                updated_at: new Date().toISOString(),
                is_favorite: false,
                confirmed_at: new Date().toISOString(),
                created_at: new Date().toISOString(),
                seller_id: 1,
                seller_nama: 'Alfian',
                seller_username: 'al.viannr',
                seller_foto_url: null,
              },
            ],
          };
        }

        // Alert toggle upsert
        if (sql.includes('INSERT INTO event_alerts (event_id, user_id, is_active, updated_at)')) {
          const key = `${params[0]}:${params[1]}`;
          const current = testAlerts.get(key) ?? false;
          const next = !current;
          testAlerts.set(key, next);
          return { rows: [{ is_active: next }] };
        }

        return { rows: [] };
      }),
    };

    app = createApp({ db: mockDb, useRateLimit: false });
  });

  it('GET /api/v1/events/popular mengembalikan daftar event populer dengan stats', async () => {
    const res = await request(app).get('/api/v1/events/popular');
    expect(res.status).toBe(200);
    expect(res.body.data).toBeDefined();
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  it('GET /api/v1/events/:id berhasil mengembalikan detail event, stats, dan listings', async () => {
    const res = await request(app).get('/api/v1/events/1');
    expect(res.status).toBe(200);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.event.id).toBe(1);
    expect(res.body.data.event.nama).toBe('Avengers: Secret Wars');
    expect(res.body.data.stats.available_tickets_count).toBe(5);
    expect(res.body.data.stats.min_price).toBe(50000);
    expect(res.body.data.stats.sellers_count).toBe(2);
    expect(res.body.data.is_alert_active).toBe(false);
    expect(Array.isArray(res.body.data.listings)).toBe(true);
    expect(res.body.data.listings.length).toBe(1);
    expect(res.body.data.listings[0].seller.username).toBe('al.viannr');
  });

  it('GET /api/v1/events/:id mengembalikan 404 jika event tidak ada', async () => {
    const res = await request(app).get('/api/v1/events/999');
    expect(res.status).toBe(404);
  });

  it('POST /api/v1/events/:id/alert gagal 401 jika tanpa login', async () => {
    const res = await request(app).post('/api/v1/events/1/alert');
    expect(res.status).toBe(401);
  });

  it('POST /api/v1/events/:id/alert berhasil mengaktifkan dan mematikan notifikasi alert', async () => {
    // Panggilan pertama: aktifkan
    const res1 = await request(app)
      .post('/api/v1/events/1/alert')
      .set('Authorization', `Bearer ${token}`);
    expect(res1.status).toBe(200);
    expect(res1.body.data.is_active).toBe(true);

    // Panggilan kedua: toggle matikan
    const res2 = await request(app)
      .post('/api/v1/events/1/alert')
      .set('Authorization', `Bearer ${token}`);
    expect(res2.status).toBe(200);
    expect(res2.body.data.is_active).toBe(false);
  });
});
