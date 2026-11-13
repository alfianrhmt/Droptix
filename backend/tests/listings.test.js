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

function createListingsMockDb() {
  const now = Date.now();
  const users = [
    {
      id: 1,
      nama: 'Rina',
      email: 'rina@example.com',
      no_wa: '6281234567890',
      kota: 'Surabaya',
      banned_at: null,
      created_at: new Date(now - 30 * 86400_000).toISOString(),
    },
    {
      id: 2,
      nama: 'Budi',
      email: 'budi@example.com',
      no_wa: null,
      kota: null,
      banned_at: null,
      created_at: new Date(now - 10 * 86400_000).toISOString(),
    },
  ];
  const categories = [
    { id: 1, slug: 'konser-festival', nama: 'Konser & Festival', ikon: 'music_note', urutan: 1 },
  ];
  const venues = [
    {
      id: 3,
      nama: 'Grand City Convention Hall',
      kota: 'Surabaya',
      alamat: 'Jl. Kusuma Bangsa',
      lat: -7.262,
      lng: 112.751,
    },
  ];
  const events = [
    {
      id: 7,
      category_id: 1,
      nama: 'Nada Senja Live in Surabaya',
      poster_url: '/uploads/a1.jpg',
      hidden: false,
    },
  ];
  const listings = [];
  const photos = [];
  const favorites = [];
  const conversations = [];
  let nextListingId = 1;
  let nextPhotoId = 1;

  function hydrateListing(l, currentUserId) {
    const e = events.find((x) => x.id === l.event_id);
    const c = categories.find((x) => x.id === e.category_id);
    const v = l.venue_id ? venues.find((x) => x.id === l.venue_id) : null;
    const u = users.find((x) => x.id === l.seller_id);
    const tertarik = conversations.filter((cv) => cv.listing_id === l.id).length;
    const isFav =
      currentUserId != null &&
      favorites.some((f) => f.user_id === currentUserId && f.listing_id === l.id);

    return {
      ...l,
      event_nama: e.nama,
      event_poster_url: e.poster_url,
      category_id: c.id,
      category_slug: c.slug,
      category_nama: c.nama,
      venue_nama: v ? v.nama : null,
      venue_kota: v ? v.kota : null,
      venue_alamat: v ? v.alamat : null,
      venue_lat: v ? v.lat : null,
      venue_lng: v ? v.lng : null,
      seller_nama: u.nama,
      seller_created_at: u.created_at,
      tertarik,
      is_favorite: isFav,
    };
  }

  return {
    users,
    events,
    listings,
    photos,
    favorites,
    query: async (sql, params = []) => {
      const q = sql.trim();

      if (q.includes('FROM users') && q.includes('WHERE id = $1')) {
        const u = users.find((x) => x.id === params[0]);
        return { rows: u ? [u] : [] };
      }

      if (q.startsWith('SELECT id, hidden FROM events WHERE id = $1')) {
        const e = events.find((x) => x.id === params[0]);
        return { rows: e ? [{ id: e.id, hidden: e.hidden }] : [] };
      }

      if (q.startsWith('SELECT id, nama, kota, lat, lng FROM venues WHERE id = $1')) {
        const v = venues.find((x) => x.id === params[0]);
        return { rows: v ? [v] : [] };
      }

      if (q.includes('FROM listings') && q.includes("interval '10 minutes'")) {
        const [sellerId, eventId, venueId, venueTeks, waktuAcara, harga] = params;
        const tenMinAgo = Date.now() - 10 * 60_000;
        const dup = listings.find(
          (l) =>
            l.seller_id === sellerId &&
            l.event_id === eventId &&
            (l.venue_id ?? 0) === (venueId ?? 0) &&
            (l.venue_teks ?? '') === (venueTeks ?? '') &&
            l.waktu_acara === waktuAcara &&
            l.harga === harga &&
            !l.deleted_at &&
            new Date(l.created_at).getTime() >= tenMinAgo
        );
        return { rows: dup ? [{ id: dup.id }] : [] };
      }

      if (q.startsWith('INSERT INTO listings')) {
        const ts = new Date().toISOString();
        const row = {
          id: nextListingId++,
          event_id: params[0],
          seller_id: params[1],
          venue_id: params[2],
          venue_teks: params[3],
          kota: params[4],
          waktu_acara: params[5],
          jenis: params[6],
          tipe: params[7],
          seksi: params[8],
          no_kursi: params[9],
          harga: params[10],
          harga_asli: params[11],
          jumlah_total: params[12],
          jumlah_terjual: 0,
          satuan: params[13],
          terikat_nama: params[14],
          serah_terima: params[15],
          lokasi_penjual_kota: params[16],
          lokasi_penjual_lat: params[17],
          lokasi_penjual_lng: params[18],
          ref_lat: params[19],
          ref_lng: params[20],
          catatan: params[21],
          izinkan_wa: params[22],
          hidden: false,
          deleted_at: null,
          created_at: ts,
          updated_at: ts,
          confirmed_at: ts,
        };
        listings.push(row);
        return { rows: [{ id: row.id }] };
      }

      if (q.startsWith('INSERT INTO listing_photos')) {
        photos.push({
          id: nextPhotoId++,
          listing_id: params[0],
          url: params[1],
          urutan: params[2],
        });
        return { rows: [] };
      }

      if (q.startsWith('DELETE FROM listing_photos')) {
        for (let i = photos.length - 1; i >= 0; i--) {
          if (photos[i].listing_id === params[0]) photos.splice(i, 1);
        }
        return { rows: [] };
      }

      if (q.includes('FROM listings l') && q.includes('WHERE l.seller_id = $1')) {
        let filtered = listings.filter(
          (l) => l.seller_id === params[0] && !l.deleted_at && !l.hidden
        );
        if (q.includes('l.waktu_acara <= now()')) {
          filtered = filtered.filter(
            (l) => new Date(l.waktu_acara).getTime() <= Date.now()
          );
        } else if (q.includes('(l.jumlah_total - l.jumlah_terjual) <= 0')) {
          filtered = filtered.filter(
            (l) =>
              new Date(l.waktu_acara).getTime() > Date.now() &&
              l.jumlah_total - l.jumlah_terjual <= 0
          );
        } else if (q.includes('(l.jumlah_total - l.jumlah_terjual) > 0')) {
          filtered = filtered.filter(
            (l) =>
              new Date(l.waktu_acara).getTime() > Date.now() &&
              l.jumlah_total - l.jumlah_terjual > 0
          );
        }

        if (q.startsWith('SELECT count(*)::int AS total')) {
          return { rows: [{ total: filtered.length }] };
        }

        const offset = params[2] || 0;
        const limit = params[1] || 20;
        const page = filtered
          .slice(offset, offset + limit)
          .map((l) => hydrateListing(l, params[0]));
        return { rows: page };
      }

      if (q.includes('FROM listings l') && q.includes('WHERE l.id = $1')) {
        const l = listings.find((x) => x.id === params[0]);
        return { rows: l ? [hydrateListing(l, params[1])] : [] };
      }

      if (q.startsWith('SELECT id, url FROM listing_photos')) {
        const rows = photos
          .filter((p) => p.listing_id === params[0])
          .sort((a, b) => a.urutan - b.urutan || a.id - b.id);
        return { rows };
      }

      if (q.startsWith('UPDATE listings') && q.includes('SET event_id = $1')) {
        const l = listings.find((x) => x.id === params[22]);
        if (l) {
          l.event_id = params[0];
          l.venue_id = params[1];
          l.venue_teks = params[2];
          l.kota = params[3];
          l.waktu_acara = params[4];
          l.jenis = params[5];
          l.tipe = params[6];
          l.seksi = params[7];
          l.no_kursi = params[8];
          l.harga = params[9];
          l.harga_asli = params[10];
          l.jumlah_total = params[11];
          l.satuan = params[12];
          l.terikat_nama = params[13];
          l.serah_terima = params[14];
          l.lokasi_penjual_kota = params[15];
          l.lokasi_penjual_lat = params[16];
          l.lokasi_penjual_lng = params[17];
          l.ref_lat = params[18];
          l.ref_lng = params[19];
          l.catatan = params[20];
          l.izinkan_wa = params[21];
          l.updated_at = new Date().toISOString();
        }
        return { rows: [] };
      }

      if (q.startsWith('UPDATE listings SET jumlah_terjual')) {
        const l = listings.find((x) => x.id === params[1]);
        if (l) {
          l.jumlah_terjual = params[0];
          l.updated_at = new Date().toISOString();
        }
        return { rows: [] };
      }

      if (q.startsWith('UPDATE listings SET confirmed_at')) {
        const l = listings.find((x) => x.id === params[0]);
        const ts = new Date().toISOString();
        if (l) {
          l.confirmed_at = ts;
          l.updated_at = ts;
        }
        return { rows: [{ confirmed_at: ts }] };
      }

      if (q.startsWith('UPDATE listings SET deleted_at')) {
        const l = listings.find((x) => x.id === params[0]);
        if (l) {
          l.deleted_at = new Date().toISOString();
          l.updated_at = l.deleted_at;
        }
        return { rows: [] };
      }

      throw new Error(`Unhandled query: ${q}`);
    },
  };
}

describe('Listings CRUD, validasi, ref_lat/ref_lng, stok, dan status turunan (T3.1)', () => {
  const futureIso = () => new Date(Date.now() + 2 * 86400_000).toISOString();

  it('POST /listings digital berhasil, mengisi ref_lat/ref_lng venue, hitung diskon, dan tolak duplikat 10 menit', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const token = makeToken(db.users[0]);

    const payload = {
      event_id: 7,
      venue_id: 3,
      kota: 'Surabaya',
      waktu_acara: futureIso(),
      jenis: 'last_minute',
      tipe: 'digital',
      seksi: 'CAT 2',
      harga: 450000,
      harga_asli: 600000,
      jumlah_total: 2,
      satuan: true,
      terikat_nama: 'tidak',
      serah_terima: ['transfer_eticket'],
      catatan: 'Tidak bisa hadir.',
      izinkan_wa: true,
      photos: ['/uploads/p1.jpg'],
    };

    const res = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    expect(res.status).toBe(201);
    const data = res.body.data;
    expect(data.status).toBe('tersedia');
    expect(data.diskon_persen).toBe(25);
    expect(data.jumlah_tersedia).toBe(2);
    expect(data.izinkan_wa).toBe(true);
    expect(data.seller.no_wa).toBeUndefined();
    expect(db.listings[0].ref_lat).toBe(-7.262);
    expect(db.listings[0].ref_lng).toBe(112.751);

    const dup = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('CONFLICT');
  });

  it('POST /listings menolak profil tanpa kota, izinkan_wa tanpa no_wa, dan validasi serah_terima/foto', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const noCityToken = makeToken(db.users[1]);

    const noCityRes = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${noCityToken}`)
      .send({
        event_id: 7,
        venue_id: 3,
        waktu_acara: futureIso(),
        jenis: 'limited',
        tipe: 'digital',
        harga: 200000,
        jumlah_total: 1,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/p1.jpg'],
      });
    expect(noCityRes.status).toBe(422);

    db.users[1].kota = 'Jakarta';
    const noWaRes = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${noCityToken}`)
      .send({
        event_id: 7,
        venue_id: 3,
        waktu_acara: futureIso(),
        jenis: 'limited',
        tipe: 'digital',
        harga: 200000,
        jumlah_total: 1,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        izinkan_wa: true,
        photos: ['/uploads/p1.jpg'],
      });
    expect(noWaRes.status).toBe(422);

    const badFisik = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${noCityToken}`)
      .send({
        event_id: 7,
        venue_id: 3,
        waktu_acara: futureIso(),
        jenis: 'limited',
        tipe: 'fisik',
        harga: 200000,
        jumlah_total: 1,
        terikat_nama: 'ya',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/p1.jpg'],
      });
    expect(badFisik.status).toBe(422);
    expect(badFisik.body.error.details.length).toBeGreaterThanOrEqual(2);
  });

  it('POST /listings fisik memakai lokasi_penjual_lat/lng untuk ref_lat/ref_lng dan GET /listings/:id hitung jarak_km', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const token = makeToken(db.users[0]);

    const res = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${token}`)
      .send({
        event_id: 7,
        venue_teks: 'Gelora Bung Tomo',
        kota: 'Surabaya',
        waktu_acara: futureIso(),
        jenis: 'limited',
        tipe: 'fisik',
        harga: 300000,
        jumlah_total: 2,
        terikat_nama: 'tidak_tahu',
        serah_terima: ['cod', 'ekspedisi'],
        lokasi_penjual_kota: 'Surabaya',
        lokasi_penjual_lat: -7.2575,
        lokasi_penjual_lng: 112.7521,
        photos: ['/uploads/p1.jpg', '/uploads/p2.jpg'],
      });
    expect(res.status).toBe(201);
    expect(db.listings[0].ref_lat).toBe(-7.2575);
    expect(db.listings[0].ref_lng).toBe(112.7521);

    const detailRes = await request(app).get(
      '/api/v1/listings/1?lat=-7.2675&lng=112.7521'
    );
    expect(detailRes.status).toBe(200);
    expect(detailRes.body.data.jarak_km).toBeGreaterThan(0);
    expect(detailRes.body.data.photos).toHaveLength(2);
  });

  it('PUT, PATCH /stock, POST /confirm, DELETE (soft), dan status hidden/kedaluwarsa bekerja sesuai kepemilikan', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const ownerToken = makeToken(db.users[0]);
    const otherToken = makeToken(db.users[1]);

    const created = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        event_id: 7,
        venue_id: 3,
        waktu_acara: futureIso(),
        jenis: 'limited',
        tipe: 'digital',
        harga: 500000,
        jumlah_total: 2,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/p1.jpg'],
      });
    expect(created.status).toBe(201);

    const forbiddenPut = await request(app)
      .put('/api/v1/listings/1')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ harga: 400000 });
    expect(forbiddenPut.status).toBe(403);

    const stockSold = await request(app)
      .patch('/api/v1/listings/1/stock')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ jumlah_terjual: 2 });
    expect(stockSold.status).toBe(200);
    expect(stockSold.body.data.status).toBe('terjual');
    expect(stockSold.body.data.jumlah_tersedia).toBe(0);

    // jumlah_total tidak boleh < jumlah_terjual (2)
    const badPut = await request(app)
      .put('/api/v1/listings/1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ jumlah_total: 1 });
    expect(badPut.status).toBe(422);

    const confirmRes = await request(app)
      .post('/api/v1/listings/1/confirm')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(confirmRes.status).toBe(200);
    expect(confirmRes.body.data.confirmed_at).toBeDefined();

    // hidden=true membuat listing berstatus dihapus -> 404 di GET /listings/:id
    db.listings[0].hidden = true;
    const hiddenGet = await request(app).get('/api/v1/listings/1');
    expect(hiddenGet.status).toBe(404);

    db.listings[0].hidden = false;
    const delRes = await request(app)
      .delete('/api/v1/listings/1')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(delRes.status).toBe(204);

    const afterDelGet = await request(app).get('/api/v1/listings/1');
    expect(afterDelGet.status).toBe(404);
  });

  it('GET /me/listings mengembalikan listing milik sendiri berpagination dan filter status', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const ownerToken = makeToken(db.users[0]);

    await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        event_id: 7,
        venue_id: 3,
        waktu_acara: futureIso(),
        jenis: 'limited',
        tipe: 'digital',
        harga: 250000,
        jumlah_total: 2,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/p1.jpg'],
      });

    const resAll = await request(app)
      .get('/api/v1/me/listings')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(resAll.status).toBe(200);
    expect(resAll.body.data).toHaveLength(1);
    expect(resAll.body.meta.total).toBe(1);
    expect(resAll.body.data[0].status).toBe('tersedia');

    const resTersedia = await request(app)
      .get('/api/v1/me/listings?status=tersedia')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(resTersedia.status).toBe(200);
    expect(resTersedia.body.data).toHaveLength(1);

    const resTerjual = await request(app)
      .get('/api/v1/me/listings?status=terjual')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(resTerjual.status).toBe(200);
    expect(resTerjual.body.data).toHaveLength(0);
  });
});

