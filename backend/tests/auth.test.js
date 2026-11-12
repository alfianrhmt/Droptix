'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/index');
const { getJwtSecret } = require('../src/middleware/auth');
const { normalizeWaNumber } = require('../src/utils/phone');

function createMockDb() {
  const users = [];
  let nextId = 1;

  return {
    users,
    query: async (sql, params = []) => {
      const q = sql.trim();
      if (q.startsWith('SELECT id FROM users WHERE email')) {
        const u = users.find((x) => x.email === params[0]);
        return { rows: u ? [{ id: u.id }] : [] };
      }
      if (q.startsWith('INSERT INTO users')) {
        const user = {
          id: nextId++,
          nama: params[0],
          email: params[1],
          password_hash: params[2],
          no_wa: params[3],
          kota: params[4],
          banned_at: null,
          created_at: new Date().toISOString(),
        };
        users.push(user);
        return {
          rows: [
            {
              id: user.id,
              nama: user.nama,
              email: user.email,
              no_wa: user.no_wa,
              kota: user.kota,
            },
          ],
        };
      }
      if (q.includes('FROM users') && q.includes('WHERE email = $1')) {
        const u = users.find((x) => x.email === params[0]);
        return { rows: u ? [u] : [] };
      }
      if (q.includes('FROM users') && q.includes('WHERE id = $1')) {
        const u = users.find((x) => x.id === params[0]);
        return { rows: u ? [u] : [] };
      }
      if (q.startsWith('UPDATE users') && q.includes('SET nama = $1')) {
        const u = users.find((x) => x.id === params[3]);
        if (!u) return { rows: [] };
        u.nama = params[0];
        u.no_wa = params[1];
        u.kota = params[2];
        return {
          rows: [
            {
              id: u.id,
              nama: u.nama,
              email: u.email,
              no_wa: u.no_wa,
              kota: u.kota,
              created_at: u.created_at,
            },
          ],
        };
      }
      if (q.startsWith('UPDATE users SET password_hash')) {
        const u = users.find((x) => x.id === params[1]);
        if (u) u.password_hash = params[0];
        return { rows: [] };
      }
      throw new Error(`Unhandled query: ${q}`);
    },
  };
}

describe('Auth, /me, validasi, format error & rate limit (T1.3)', () => {
  it('normalizeWaNumber mengubah 08... dan +62... ke format 62...', () => {
    expect(normalizeWaNumber('0812-3456-7890')).toBe('6281234567890');
    expect(normalizeWaNumber('+62 812 3456 7890')).toBe('6281234567890');
    expect(normalizeWaNumber('6281234567890')).toBe('6281234567890');
    expect(normalizeWaNumber('abc')).toBeNull();
  });

  it('register berhasil, normalisasi no_wa, dan tolak email duplikat (409)', async () => {
    const db = createMockDb();
    const app = createApp({ db, useRateLimit: false });

    const res = await request(app).post('/api/v1/auth/register').send({
      nama: 'Budi Santoso',
      email: 'Budi@Example.com',
      password: 'password123',
      setuju_syarat: true,
      no_wa: '0812-3456-7890',
      kota: 'Surabaya',
    });

    expect(res.status).toBe(201);
    expect(res.body.data.token).toBeDefined();
    expect(res.body.data.user).toEqual({
      id: 1,
      nama: 'Budi Santoso',
      email: 'budi@example.com',
      no_wa: '6281234567890',
      kota: 'Surabaya',
    });

    const dup = await request(app).post('/api/v1/auth/register').send({
      nama: 'Budi Lagi',
      email: 'budi@example.com',
      password: 'password123',
      setuju_syarat: true,
    });
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('CONFLICT');
  });

  it('register menolak setuju_syarat false dan password < 8 karakter (422)', async () => {
    const db = createMockDb();
    const app = createApp({ db, useRateLimit: false });

    const res = await request(app).post('/api/v1/auth/register').send({
      nama: 'Budi',
      email: 'budi@example.com',
      password: '123',
      setuju_syarat: false,
    });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.length).toBeGreaterThanOrEqual(2);
  });

  it('login berhasil, tolak salah kredensial (401), dan tolak akun dibekukan (403 ACCOUNT_BANNED)', async () => {
    const db = createMockDb();
    const app = createApp({ db, useRateLimit: false });

    await request(app).post('/api/v1/auth/register').send({
      nama: 'Sari',
      email: 'sari@example.com',
      password: 'password123',
      setuju_syarat: true,
    });

    const ok = await request(app).post('/api/v1/auth/login').send({
      email: 'sari@example.com',
      password: 'password123',
    });
    expect(ok.status).toBe(200);
    expect(ok.body.data.token).toBeDefined();

    const wrong = await request(app).post('/api/v1/auth/login').send({
      email: 'sari@example.com',
      password: 'salah',
    });
    expect(wrong.status).toBe(401);
    expect(wrong.body.error.code).toBe('UNAUTHORIZED');

    db.users[0].banned_at = new Date().toISOString();
    const banned = await request(app).post('/api/v1/auth/login').send({
      email: 'sari@example.com',
      password: 'password123',
    });
    expect(banned.status).toBe(403);
    expect(banned.body.error.code).toBe('ACCOUNT_BANNED');
  });

  it('GET /me, PUT /me, dan PUT /me/password berjalan serta menolak token kedaluwarsa', async () => {
    const db = createMockDb();
    const app = createApp({ db, useRateLimit: false });

    const reg = await request(app).post('/api/v1/auth/register').send({
      nama: 'Rina',
      email: 'rina@example.com',
      password: 'password123',
      setuju_syarat: true,
    });
    const token = reg.body.data.token;

    const me = await request(app)
      .get('/api/v1/me')
      .set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(200);
    expect(me.body.data.email).toBe('rina@example.com');
    expect(me.body.data.password_hash).toBeUndefined();

    const upd = await request(app)
      .put('/api/v1/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ nama: 'Rina Wijaya', no_wa: '081999888777', kota: 'Bandung' });
    expect(upd.status).toBe(200);
    expect(upd.body.data.nama).toBe('Rina Wijaya');
    expect(upd.body.data.no_wa).toBe('6281999888777');
    expect(upd.body.data.kota).toBe('Bandung');

    const badPass = await request(app)
      .put('/api/v1/me/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ password_lama: 'salah', password_baru: 'baru12345' });
    expect(badPass.status).toBe(422);
    expect(badPass.body.error.code).toBe('VALIDATION_ERROR');

    const okPass = await request(app)
      .put('/api/v1/me/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ password_lama: 'password123', password_baru: 'baru12345' });
    expect(okPass.status).toBe(200);
    expect(okPass.body.data.ok).toBe(true);

    const expiredToken = jwt.sign(
      { sub: 1, email: 'rina@example.com' },
      getJwtSecret(),
      { expiresIn: -10 }
    );
    const expRes = await request(app)
      .get('/api/v1/me')
      .set('Authorization', `Bearer ${expiredToken}`);
    expect(expRes.status).toBe(401);
    expect(expRes.body.error.code).toBe('UNAUTHORIZED');
  });

  it('rate limiter mengembalikan 429 RATE_LIMITED setelah melewati batas /auth/*', async () => {
    const db = createMockDb();
    const app = createApp({ db, useRateLimit: true });

    let lastStatus = 200;
    let lastBody = null;
    for (let i = 0; i < 11; i++) {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'a@b.com', password: 'x' });
      lastStatus = res.status;
      lastBody = res.body;
    }

    expect(lastStatus).toBe(429);
    expect(lastBody.error.code).toBe('RATE_LIMITED');
  });
});
