'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/index');
const { getJwtSecret } = require('../src/middleware/auth');
const { detectImageExtension } = require('../src/routes/uploads');

function makeToken(user) {
  return jwt.sign({ sub: user.id, email: user.email }, getJwtSecret(), {
    expiresIn: '1h',
  });
}

function createMasterMockDb() {
  const users = [
    { id: 1, nama: 'Rina', email: 'rina@example.com', banned_at: null },
    { id: 2, nama: 'Budi', email: 'budi@example.com', banned_at: null },
  ];
  const categories = [
    { id: 1, slug: 'konser-festival', nama: 'Konser & Festival', ikon: 'music_note', urutan: 1 },
    { id: 2, slug: 'bioskop', nama: 'Bioskop', ikon: 'movie', urutan: 2 },
    { id: 3, slug: 'olahraga', nama: 'Olahraga', ikon: 'sports_soccer', urutan: 3 },
  ];
  const venues = [
    {
      id: 1,
      nama: 'Stadion Gelora Bung Karno',
      kota: 'Jakarta',
      alamat: 'Jl. Pintu Satu Senayan',
      lat: -6.2186,
      lng: 106.8025,
    },
    {
      id: 2,
      nama: 'Grand City Convention Hall',
      kota: 'Surabaya',
      alamat: 'Jl. Kusuma Bangsa',
      lat: -7.262,
      lng: 112.751,
    },
  ];
  const events = [
    {
      id: 1,
      category_id: 1,
      nama: 'Nada Senja Live in Surabaya',
      nama_normal: 'nada senja live in surabaya',
      poster_url: null,
      venue_id: 2,
      tanggal: new Date(Date.now() + 7 * 86400_000).toISOString(),
      created_by: 1,
      created_at: new Date().toISOString(),
      hidden: false,
    },
  ];
  const listings = [];
  let nextEventId = 2;

  function hydrateEvent(e) {
    const c = categories.find((x) => x.id === e.category_id);
    const v = e.venue_id ? venues.find((x) => x.id === e.venue_id) : null;
    return {
      id: e.id,
      nama: e.nama,
      poster_url: e.poster_url,
      tanggal: e.tanggal,
      created_by: e.created_by,
      hidden: e.hidden,
      category_id: c.id,
      category_slug: c.slug,
      category_nama: c.nama,
      category_ikon: c.ikon,
      venue_id: v ? v.id : null,
      venue_nama: v ? v.nama : null,
      venue_kota: v ? v.kota : null,
      venue_alamat: v ? v.alamat : null,
      venue_lat: v ? v.lat : null,
      venue_lng: v ? v.lng : null,
    };
  }

  return {
    users,
    categories,
    venues,
    events,
    listings,
    query: async (sql, params = []) => {
      const q = sql.trim();

      if (q.includes('FROM users') && q.includes('WHERE id = $1')) {
        const u = users.find((x) => x.id === params[0]);
        return { rows: u ? [u] : [] };
      }

      if (q.startsWith('SELECT id, slug, nama, ikon, urutan FROM categories')) {
        return { rows: [...categories].sort((a, b) => a.urutan - b.urutan) };
      }

      if (q.startsWith('SELECT id, slug, nama, ikon FROM categories WHERE id = $1')) {
        const c = categories.find((x) => x.id === params[0]);
        return { rows: c ? [c] : [] };
      }

      if (q.startsWith('SELECT id, nama, kota, alamat, lat, lng') && q.includes('FROM venues')) {
        let rows = [...venues];
        let idx = 0;
        if (q.includes('nama ILIKE')) {
          const term = params[idx++].replace(/%/g, '').toLowerCase();
          rows = rows.filter((v) => v.nama.toLowerCase().includes(term));
        }
        if (q.includes('LOWER(kota) = LOWER')) {
          const kota = params[idx++].toLowerCase();
          rows = rows.filter((v) => v.kota.toLowerCase() === kota);
        }
        const limit = params[idx];
        return { rows: rows.slice(0, limit) };
      }

      if (q.startsWith('SELECT id FROM venues WHERE id = $1')) {
        const v = venues.find((x) => x.id === params[0]);
        return { rows: v ? [{ id: v.id }] : [] };
      }

      if (q.includes('FROM events e') && q.includes('WHERE e.id = $1')) {
        const e = events.find((x) => x.id === params[0]);
        return { rows: e ? [hydrateEvent(e)] : [] };
      }

      if (q.includes('FROM events e') && q.includes('LIMIT 10')) {
        let rows = events.filter((e) => !e.hidden);
        let idx = 0;
        if (q.includes('e.nama_normal LIKE')) {
          const term = params[idx++].replace(/%/g, '');
          rows = rows.filter((e) => e.nama_normal.includes(term));
        }
        if (q.includes('c.slug =')) {
          const slug = params[idx++];
          rows = rows.filter((e) => {
            const c = categories.find((x) => x.id === e.category_id);
            return c && c.slug === slug;
          });
        }
        return { rows: rows.slice(0, 10).map(hydrateEvent) };
      }

      if (q.includes('COUNT(*)::int AS total') && q.includes('FROM events')) {
        const count = events.filter((e) => e.created_by === params[0]).length;
        return { rows: [{ total: count }] };
      }

      if (q.includes('similarity(nama_normal')) {
        const categoryId = params[0];
        const term = params[1];
        const similar = events
          .filter(
            (e) =>
              e.category_id === categoryId &&
              !e.hidden &&
              (e.nama_normal.includes(term) || term.includes(e.nama_normal) || e.nama_normal === term)
          )
          .map((e) => ({ id: e.id, nama: e.nama, poster_url: e.poster_url }));
        return { rows: similar };
      }

      if (q.startsWith('INSERT INTO events')) {
        const created = {
          id: nextEventId++,
          category_id: params[0],
          nama: params[1],
          nama_normal: params[2],
          poster_url: params[3],
          venue_id: params[4],
          tanggal: params[5],
          created_by: params[6],
          created_at: new Date().toISOString(),
          hidden: false,
        };
        events.push(created);
        return { rows: [{ id: created.id }] };
      }

      if (q.includes('FROM listings') && q.includes('seller_id <> $2')) {
        const hasOther = listings.some(
          (l) => l.event_id === params[0] && l.seller_id !== params[1] && !l.deleted_at
        );
        return { rows: hasOther ? [{ '?column?': 1 }] : [] };
      }

      if (q.startsWith('UPDATE events')) {
        const e = events.find((x) => x.id === params[5]);
        if (e) {
          e.nama = params[0];
          e.nama_normal = params[1];
          e.poster_url = params[2];
          e.venue_id = params[3];
          e.tanggal = params[4];
        }
        return { rows: [] };
      }

      throw new Error(`Unhandled query: ${q}`);
    },
  };
}

describe('Master data: categories, venues, events, uploads (T2.1 & T2.4)', () => {
  let uploadsDir;

  beforeEach(() => {
    uploadsDir = fs.mkdtempSync(path.join(os.tmpdir(), 'droptix-uploads-'));
  });

  afterEach(() => {
    fs.rmSync(uploadsDir, { recursive: true, force: true });
  });

  it('GET /categories mengembalikan kategori terurut dan GET /venues memfilter q & kota', async () => {
    const db = createMasterMockDb();
    const app = createApp({ db, useRateLimit: false, uploadsDir });

    const catRes = await request(app).get('/api/v1/categories');
    expect(catRes.status).toBe(200);
    expect(catRes.body.data.map((c) => c.slug)).toEqual([
      'konser-festival',
      'bioskop',
      'olahraga',
    ]);

    const venueRes = await request(app).get('/api/v1/venues?q=grand&kota=surabaya');
    expect(venueRes.status).toBe(200);
    expect(venueRes.body.data).toHaveLength(1);
    expect(venueRes.body.data[0].nama).toBe('Grand City Convention Hall');
  });

  it('POST /events mewajibkan venue_id & tanggal untuk Konser/Olahraga, cek nama mirip, dukung force, dan batas 5/hari', async () => {
    const db = createMasterMockDb();
    const app = createApp({ db, useRateLimit: false, uploadsDir });
    const token = makeToken(db.users[0]);
    const futureIso = new Date(Date.now() + 3 * 86400_000).toISOString();

    const missingVenue = await request(app)
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${token}`)
      .send({ category_id: 1, nama: 'Konser Baru' });
    expect(missingVenue.status).toBe(422);
    expect(missingVenue.body.error.code).toBe('VALIDATION_ERROR');

    const similarRes = await request(app)
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${token}`)
      .send({
        category_id: 1,
        nama: 'Nada Senja Live in Surabaya',
        venue_id: 2,
        tanggal: futureIso,
      });
    expect(similarRes.status).toBe(409);
    expect(similarRes.body.error.code).toBe('SIMILAR_EVENT_EXISTS');
    expect(similarRes.body.error.similar).toHaveLength(1);

    const forcedRes = await request(app)
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${token}`)
      .send({
        category_id: 1,
        nama: 'Nada Senja Live in Surabaya',
        venue_id: 2,
        tanggal: futureIso,
        force: true,
      });
    expect(forcedRes.status).toBe(201);
    expect(forcedRes.body.data.nama).toBe('Nada Senja Live in Surabaya');

    // User 1 sudah punya 2 event (seed + forced); buat 3 lagi hingga total 5, lalu yang ke-6 kena 429
    for (let i = 0; i < 3; i++) {
      const r = await request(app)
        .post('/api/v1/events')
        .set('Authorization', `Bearer ${token}`)
        .send({ category_id: 2, nama: `Film Baru ${i}` });
      expect(r.status).toBe(201);
    }

    const sixthRes = await request(app)
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${token}`)
      .send({ category_id: 2, nama: 'Film Keenam' });
    expect(sixthRes.status).toBe(429);
    expect(sixthRes.body.error.code).toBe('RATE_LIMITED');
  });

  it('PUT /events/:id hanya untuk pembuat dan terkunci (403 EVENT_LOCKED) jika ada listing penjual lain', async () => {
    const db = createMasterMockDb();
    const app = createApp({ db, useRateLimit: false, uploadsDir });
    const ownerToken = makeToken(db.users[0]);
    const otherToken = makeToken(db.users[1]);

    const nonOwnerRes = await request(app)
      .put('/api/v1/events/1')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ nama: 'Ubah oleh Orang Lain' });
    expect(nonOwnerRes.status).toBe(403);
    expect(nonOwnerRes.body.error.code).toBe('FORBIDDEN');

    const okUpdate = await request(app)
      .put('/api/v1/events/1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ nama: 'Nada Senja Live Updated' });
    expect(okUpdate.status).toBe(200);
    expect(okUpdate.body.data.nama).toBe('Nada Senja Live Updated');

    db.listings.push({ id: 10, event_id: 1, seller_id: 2, deleted_at: null });
    const lockedRes = await request(app)
      .put('/api/v1/events/1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ nama: 'Tidak Bisa Diubah' });
    expect(lockedRes.status).toBe(403);
    expect(lockedRes.body.error.code).toBe('EVENT_LOCKED');
  });

  it('GET /events memfilter q & category serta menyembunyikan event hidden', async () => {
    const db = createMasterMockDb();
    db.events.push({
      id: 99,
      category_id: 2,
      nama: 'Film Rahasia',
      nama_normal: 'film rahasia',
      poster_url: null,
      venue_id: null,
      tanggal: null,
      created_by: 1,
      created_at: new Date().toISOString(),
      hidden: true,
    });
    const app = createApp({ db, useRateLimit: false, uploadsDir });

    const res = await request(app).get('/api/v1/events?q=nada&category=konser-festival');
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].nama).toBe('Nada Senja Live in Surabaya');

    const hiddenRes = await request(app).get('/api/v1/events?q=rahasia');
    expect(hiddenRes.status).toBe(200);
    expect(hiddenRes.body.data).toHaveLength(0);
  });

  it('POST /events menolak tanpa login, tanggal lampau, dan kategori olahraga tanpa venue/tanggal, serta izinkan nama sama di kategori lain', async () => {
    const db = createMasterMockDb();
    const app = createApp({ db, useRateLimit: false, uploadsDir });
    const token = makeToken(db.users[1]);

    const unauth = await request(app)
      .post('/api/v1/events')
      .send({ category_id: 2, nama: 'Film Tanpa Login' });
    expect(unauth.status).toBe(401);

    const pastDate = new Date(Date.now() - 3600_000).toISOString();
    const pastRes = await request(app)
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${token}`)
      .send({
        category_id: 3,
        nama: 'Persib vs Persija',
        venue_id: 1,
        tanggal: pastDate,
      });
    expect(pastRes.status).toBe(422);

    const sportMissing = await request(app)
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${token}`)
      .send({ category_id: 3, nama: 'Persib vs Persija' });
    expect(sportMissing.status).toBe(422);

    // Nama mirip tapi di kategori berbeda (bioskop) tetap lolos tanpa force
    const diffCat = await request(app)
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${token}`)
      .send({ category_id: 2, nama: 'Nada Senja Live in Surabaya' });
    expect(diffCat.status).toBe(201);
  });

  it('PUT /events/:id tidak terkunci oleh listing pembuat sendiri atau listing terhapus, hanya oleh listing aktif penjual lain', async () => {
    const db = createMasterMockDb();
    const app = createApp({ db, useRateLimit: false, uploadsDir });
    const ownerToken = makeToken(db.users[0]);

    db.listings.push({ id: 1, event_id: 1, seller_id: 1, deleted_at: null });
    db.listings.push({
      id: 2,
      event_id: 1,
      seller_id: 2,
      deleted_at: new Date().toISOString(),
    });

    const stillEditable = await request(app)
      .put('/api/v1/events/1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ nama: 'Nada Senja Revisi Pembuat' });
    expect(stillEditable.status).toBe(200);

    db.listings.push({ id: 3, event_id: 1, seller_id: 2, deleted_at: null });
    const locked = await request(app)
      .put('/api/v1/events/1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ nama: 'Harusnya Gagal' });
    expect(locked.status).toBe(403);
    expect(locked.body.error.code).toBe('EVENT_LOCKED');
  });

  it('POST /uploads memvalidasi magic bytes isi berkas, menyimpan file acak, dan menyajikan /uploads', async () => {
    const db = createMasterMockDb();
    const app = createApp({ db, useRateLimit: false, uploadsDir });
    const token = makeToken(db.users[0]);

    expect(detectImageExtension(Buffer.from('hello world!!'))).toBeNull();

    const fakeImg = await request(app)
      .post('/api/v1/uploads')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', Buffer.from('bukan gambar sama sekali'), 'palsu.jpg');
    expect(fakeImg.status).toBe(422);
    expect(fakeImg.body.error.code).toBe('VALIDATION_ERROR');

    // Header PNG valid minimal 16 byte
    const pngBytes = Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    ]);
    const okUpload = await request(app)
      .post('/api/v1/uploads')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', pngBytes, 'poster.png');
    expect(okUpload.status).toBe(201);
    expect(okUpload.body.data.url).toMatch(/^\/uploads\/[a-f0-9]{32}\.png$/);

    const staticRes = await request(app).get(okUpload.body.data.url);
    expect(staticRes.status).toBe(200);

    const oversized = Buffer.alloc(2 * 1024 * 1024 + 10, 0xff);
    oversized[0] = 0xff;
    oversized[1] = 0xd8;
    oversized[2] = 0xff;
    const bigRes = await request(app)
      .post('/api/v1/uploads')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', oversized, 'besar.jpg');
    expect(bigRes.status).toBe(422);
    expect(bigRes.body.error.code).toBe('VALIDATION_ERROR');
  });
});

