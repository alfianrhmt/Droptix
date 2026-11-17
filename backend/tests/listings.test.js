'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/index');
const { getJwtSecret } = require('../src/middleware/auth');
const { haversineKm, getWibDateRange } = require('../src/routes/listings');

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
    {
      id: 3,
      nama: 'Banned Seller',
      email: 'banned@example.com',
      no_wa: '628999999999',
      kota: 'Jakarta',
      banned_at: new Date(now - 86400_000).toISOString(),
      created_at: new Date(now - 60 * 86400_000).toISOString(),
    },
  ];
  const categories = [
    { id: 1, slug: 'konser-festival', nama: 'Konser & Festival', ikon: 'music_note', urutan: 1 },
    { id: 2, slug: 'bioskop', nama: 'Bioskop', ikon: 'movie', urutan: 2 },
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
    {
      id: 4,
      nama: 'Gelora Bung Karno',
      kota: 'Jakarta',
      alamat: 'Senayan',
      lat: -6.218,
      lng: 106.802,
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
    {
      id: 8,
      category_id: 2,
      nama: 'Midnight Movie Premiere',
      poster_url: '/uploads/a2.jpg',
      hidden: false,
    },
    {
      id: 9,
      category_id: 1,
      nama: 'Hidden Festival',
      poster_url: null,
      hidden: true,
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
    const c = e ? categories.find((x) => x.id === e.category_id) : null;
    const v = l.venue_id ? venues.find((x) => x.id === l.venue_id) : null;
    const u = users.find((x) => x.id === l.seller_id);
    const tertarik = conversations.filter((cv) => cv.listing_id === l.id).length;
    const isFav =
      currentUserId != null &&
      favorites.some((f) => f.user_id === currentUserId && f.listing_id === l.id);

    return {
      ...l,
      event_nama: e ? e.nama : 'Event',
      event_poster_url: e ? e.poster_url : null,
      category_id: c ? c.id : 1,
      category_slug: c ? c.slug : 'konser-festival',
      category_nama: c ? c.nama : 'Konser & Festival',
      venue_nama: v ? v.nama : null,
      venue_kota: v ? v.kota : null,
      venue_alamat: v ? v.alamat : null,
      venue_lat: v ? v.lat : null,
      venue_lng: v ? v.lng : null,
      seller_nama: u ? u.nama : 'Seller',
      seller_created_at: u ? u.created_at : new Date().toISOString(),
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

      if (
        q.includes('FROM listings l') &&
        q.includes('JOIN events e') &&
        !q.includes('WHERE l.seller_id = $1') &&
        !q.includes('WHERE l.id = $1')
      ) {
        let filtered = listings.filter((l) => {
          if (l.deleted_at || l.hidden) return false;
          if (new Date(l.waktu_acara).getTime() <= Date.now()) return false;
          const seller = users.find((u) => u.id === l.seller_id);
          if (!seller || seller.banned_at) return false;
          const ev = events.find((e) => e.id === l.event_id);
          if (!ev || ev.hidden) return false;
          return true;
        });

        if (q.includes('(l.jumlah_total - l.jumlah_terjual) > 0')) {
          filtered = filtered.filter(
            (l) => l.jumlah_total - l.jumlah_terjual > 0
          );
        }

        const matchQ = /e\.nama ILIKE \$(\d+)/.exec(q);
        if (matchQ) {
          const rawVal = params[parseInt(matchQ[1], 10) - 1] || '';
          const searchStr = rawVal.replace(/^%|%$/g, '').toLowerCase();
          filtered = filtered.filter((l) => {
            const ev = events.find((e) => e.id === l.event_id);
            const vn = l.venue_id ? venues.find((v) => v.id === l.venue_id) : null;
            return (
              (ev && ev.nama.toLowerCase().includes(searchStr)) ||
              (vn && vn.nama.toLowerCase().includes(searchStr)) ||
              (l.venue_teks && l.venue_teks.toLowerCase().includes(searchStr)) ||
              (l.kota && l.kota.toLowerCase().includes(searchStr))
            );
          });
        }

        const matchCat = /c\.slug = \$(\d+)/.exec(q);
        if (matchCat) {
          const catSlug = params[parseInt(matchCat[1], 10) - 1];
          filtered = filtered.filter((l) => {
            const ev = events.find((e) => e.id === l.event_id);
            const cat = ev ? categories.find((c) => c.id === ev.category_id) : null;
            return cat && cat.slug === catSlug;
          });
        }

        const matchJenis = /l\.jenis = \$(\d+)/.exec(q);
        if (matchJenis) {
          const jenisVal = params[parseInt(matchJenis[1], 10) - 1];
          filtered = filtered.filter((l) => l.jenis === jenisVal);
        }

        const matchTipe = /l\.tipe = \$(\d+)/.exec(q);
        if (matchTipe) {
          const tipeVal = params[parseInt(matchTipe[1], 10) - 1];
          filtered = filtered.filter((l) => l.tipe === tipeVal);
        }

        const matchKota = /(?:^|\sAND\s+)l\.kota ILIKE \$(\d+)/.exec(q);
        if (matchKota) {
          const kotaVal = (params[parseInt(matchKota[1], 10) - 1] || '').toLowerCase();
          filtered = filtered.filter((l) => (l.kota || '').toLowerCase() === kotaVal);
        }

        const matchMinHarga = /l\.harga >= \$(\d+)/.exec(q);
        if (matchMinHarga) {
          const minH = params[parseInt(matchMinHarga[1], 10) - 1];
          filtered = filtered.filter((l) => l.harga >= minH);
        }

        const matchMaxHarga = /l\.harga <= \$(\d+)/.exec(q);
        if (matchMaxHarga) {
          const maxH = params[parseInt(matchMaxHarga[1], 10) - 1];
          filtered = filtered.filter((l) => l.harga <= maxH);
        }

        const matchDateRange = /l\.waktu_acara >= \$(\d+) AND l\.waktu_acara <= \$(\d+)/.exec(q);
        if (matchDateRange) {
          const start = new Date(params[parseInt(matchDateRange[1], 10) - 1]).getTime();
          const end = new Date(params[parseInt(matchDateRange[2], 10) - 1]).getTime();
          filtered = filtered.filter((l) => {
            const t = new Date(l.waktu_acara).getTime();
            return t >= start && t <= end;
          });
        }

        const matchDalamJam = /(?:^|\s)l\.waktu_acara <= \$(\d+)/.exec(q);
        if (matchDalamJam && (!matchDateRange || parseInt(matchDalamJam[1], 10) !== parseInt(matchDateRange[2], 10))) {
          const deadline = new Date(params[parseInt(matchDalamJam[1], 10) - 1]).getTime();
          filtered = filtered.filter((l) => new Date(l.waktu_acara).getTime() <= deadline);
        }

        const matchMaxKm = /l\.ref_lat IS NOT NULL.*<= \$(\d+)/.exec(q);
        if (matchMaxKm) {
          const maxKmIdx = parseInt(matchMaxKm[1], 10) - 1;
          const maxKmVal = params[maxKmIdx];
          const uLng = params[maxKmIdx - 1];
          const uLat = params[maxKmIdx - 2];
          filtered = filtered.filter((l) => {
            if (l.ref_lat == null || l.ref_lng == null) return false;
            const dist = haversineKm(uLat, uLng, l.ref_lat, l.ref_lng);
            return dist != null && dist <= maxKmVal;
          });
        }

        // Sorting
        if (q.includes('ORDER BY (CASE WHEN l.ref_lat IS NOT NULL')) {
          const matchSortLat = /radians\(l\.ref_lat - \$(\d+)\)/.exec(q);
          const matchSortLng = /radians\(l\.ref_lng - \$(\d+)\)/.exec(q);
          const sLat = matchSortLat ? params[parseInt(matchSortLat[1], 10) - 1] : null;
          const sLng = matchSortLng ? params[parseInt(matchSortLng[1], 10) - 1] : null;
          filtered.sort((a, b) => {
            const distA = haversineKm(sLat, sLng, a.ref_lat, a.ref_lng) ?? 999999;
            const distB = haversineKm(sLat, sLng, b.ref_lat, b.ref_lng) ?? 999999;
            if (distA !== distB) return distA - distB;
            const tA = new Date(a.waktu_acara).getTime();
            const tB = new Date(b.waktu_acara).getTime();
            if (tA !== tB) return tA - tB;
            return b.id - a.id;
          });
        } else if (q.includes('ORDER BY l.harga ASC')) {
          filtered.sort(
            (a, b) =>
              a.harga - b.harga ||
              new Date(a.waktu_acara).getTime() - new Date(b.waktu_acara).getTime() ||
              b.id - a.id
          );
        } else if (q.includes('ORDER BY l.waktu_acara ASC')) {
          filtered.sort(
            (a, b) =>
              new Date(a.waktu_acara).getTime() - new Date(b.waktu_acara).getTime() ||
              b.id - a.id
          );
        } else {
          // Default terbaru / relevan
          filtered.sort(
            (a, b) =>
              new Date(b.created_at).getTime() - new Date(a.created_at).getTime() ||
              b.id - a.id
          );
        }

        if (q.startsWith('SELECT count(*)::int AS total')) {
          return { rows: [{ total: filtered.length }] };
        }

        const offset = params[params.length - 1] || 0;
        const limit = params[params.length - 2] || 20;
        const currentUserId = params[params.length - 3] || null;
        const page = filtered
          .slice(offset, offset + limit)
          .map((l) => hydrateListing(l, currentUserId));
        return { rows: page };
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

describe('T3.4 Tes Validasi Listing, Aturan Stok, Status Turunan, dan Kepemilikan (Skenario 4 & 7)', () => {
  const futureIso = (days = 2) =>
    new Date(Date.now() + days * 86400_000).toISOString();
  const pastIso = (days = 2) =>
    new Date(Date.now() - days * 86400_000).toISOString();

  it('Validasi listing menolak waktu acara lampau, path foto ilegal, dan event tidak valid/hidden', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const token = makeToken(db.users[0]);

    // 1. Waktu acara lampau
    const pastRes = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${token}`)
      .send({
        event_id: 7,
        venue_id: 3,
        waktu_acara: pastIso(),
        jenis: 'last_minute',
        tipe: 'digital',
        harga: 100000,
        jumlah_total: 1,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/p1.jpg'],
      });
    expect(pastRes.status).toBe(422);
    expect(pastRes.body.error.details.some((d) => d.field === 'waktu_acara')).toBe(true);

    // 2. Foto di luar /uploads/
    const badPhotoRes = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${token}`)
      .send({
        event_id: 7,
        venue_id: 3,
        waktu_acara: futureIso(),
        jenis: 'last_minute',
        tipe: 'digital',
        harga: 100000,
        jumlah_total: 1,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['https://external.com/photo.jpg'],
      });
    expect(badPhotoRes.status).toBe(422);

    // 3. Event tidak ada
    const badEventRes = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${token}`)
      .send({
        event_id: 9999,
        venue_id: 3,
        waktu_acara: futureIso(),
        jenis: 'last_minute',
        tipe: 'digital',
        harga: 100000,
        jumlah_total: 1,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/p1.jpg'],
      });
    expect(badEventRes.status).toBe(422);
  });

  it('Menolak aksi listing bagi tamu tanpa token autentikasi (401)', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });

    const postRes = await request(app).post('/api/v1/listings').send({});
    expect(postRes.status).toBe(401);

    const putRes = await request(app).put('/api/v1/listings/1').send({});
    expect(putRes.status).toBe(401);

    const patchRes = await request(app).patch('/api/v1/listings/1/stock').send({});
    expect(patchRes.status).toBe(401);

    const confirmRes = await request(app).post('/api/v1/listings/1/confirm').send({});
    expect(confirmRes.status).toBe(401);

    const deleteRes = await request(app).delete('/api/v1/listings/1').send({});
    expect(deleteRes.status).toBe(401);

    const myListingsRes = await request(app).get('/api/v1/me/listings').send();
    expect(myListingsRes.status).toBe(401);
  });

  it('Aturan stok menolak nilai negatif dan bukan pemilik tidak dapat mengubah listing', async () => {
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
        harga: 300000,
        jumlah_total: 3,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/p1.jpg'],
      });
    const id = created.body.data.id;

    // Stok negatif -> 422
    const negStock = await request(app)
      .patch(`/api/v1/listings/${id}/stock`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ jumlah_terjual: -1 });
    expect(negStock.status).toBe(422);

    // Orang lain mencoba ubah stok -> 403
    const forbiddenStock = await request(app)
      .patch(`/api/v1/listings/${id}/stock`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ jumlah_terjual: 1 });
    expect(forbiddenStock.status).toBe(403);

    // Orang lain mencoba konfirmasi -> 403
    const forbiddenConfirm = await request(app)
      .post(`/api/v1/listings/${id}/confirm`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(forbiddenConfirm.status).toBe(403);

    // Orang lain mencoba hapus -> 403
    const forbiddenDelete = await request(app)
      .delete(`/api/v1/listings/${id}`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(forbiddenDelete.status).toBe(403);
  });

  it('Skenario Uji 4 & 7: Penjual posting Last-Minute (digital) lalu tandai terjual semua (jumlah_terjual == total)', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const ownerToken = makeToken(db.users[0]);

    // Skenario 4: Penjual posting Last-Minute (digital)
    const postRes = await request(app)
      .post('/api/v1/listings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        event_id: 7,
        venue_id: 3,
        kota: 'Surabaya',
        waktu_acara: futureIso(3),
        jenis: 'last_minute',
        tipe: 'digital',
        seksi: 'VIP A',
        harga: 400000,
        harga_asli: 500000,
        jumlah_total: 2,
        satuan: true,
        terikat_nama: 'tidak',
        serah_terima: ['transfer_eticket'],
        photos: ['/uploads/lm1.jpg'],
      });
    expect(postRes.status).toBe(201);
    expect(postRes.body.data.jenis).toBe('last_minute');
    expect(postRes.body.data.status).toBe('tersedia');
    expect(postRes.body.data.jumlah_tersedia).toBe(2);

    const listingId = postRes.body.data.id;

    // Skenario 7: Penjual mengubah jumlah terjual menjadi sama dengan total (2 terjual dari 2 total)
    const patchRes = await request(app)
      .patch(`/api/v1/listings/${listingId}/stock`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ jumlah_terjual: 2 });
    expect(patchRes.status).toBe(200);
    expect(patchRes.body.data.status).toBe('terjual');
    expect(patchRes.body.data.jumlah_tersedia).toBe(0);
    expect(patchRes.body.data.jumlah_terjual).toBe(2);

    // Periksa status di GET /me/listings?status=terjual
    const myTerjual = await request(app)
      .get('/api/v1/me/listings?status=terjual')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(myTerjual.status).toBe(200);
    expect(myTerjual.body.data.some((l) => l.id === listingId)).toBe(true);

    // Di filter status=tersedia sudah tidak muncul
    const myTersedia = await request(app)
      .get('/api/v1/me/listings?status=tersedia')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(myTersedia.status).toBe(200);
    expect(myTersedia.body.data.some((l) => l.id === listingId)).toBe(false);
  });
});

describe('Pencarian, filter, urutan, pagination, dan jarak GET /listings (T4.1)', () => {
  function insertListing(db, overrides = {}) {
    const id = db.listings.length + 1;
    const now = Date.now();
    const listing = {
      id,
      event_id: 7,
      seller_id: 1,
      venue_id: 3,
      venue_teks: null,
      kota: 'Surabaya',
      waktu_acara: new Date(now + 48 * 3600_000).toISOString(),
      jenis: 'limited',
      tipe: 'digital',
      seksi: 'CAT 1',
      no_kursi: 'A1',
      harga: 500000,
      harga_asli: 600000,
      jumlah_total: 2,
      jumlah_terjual: 0,
      satuan: true,
      terikat_nama: 'tidak',
      serah_terima: ['transfer_eticket'],
      lokasi_penjual_kota: null,
      lokasi_penjual_lat: null,
      lokasi_penjual_lng: null,
      ref_lat: -7.262,
      ref_lng: 112.751,
      catatan: null,
      izinkan_wa: false,
      hidden: false,
      deleted_at: null,
      created_at: new Date(now - 3600_000).toISOString(),
      updated_at: new Date(now - 3600_000).toISOString(),
      confirmed_at: new Date(now - 3600_000).toISOString(),
      ...overrides,
    };
    db.listings.push(listing);
    return listing;
  }

  describe('Helper getWibDateRange', () => {
    it('menghitung rentang hari_ini, besok, dan YYYY-MM-DD sesuai zona WIB (UTC+7)', () => {
      // Rabu 12 Nov 2026 10:00:00 WIB (UTC 03:00:00)
      const nowWib = new Date('2026-11-12T03:00:00.000Z');

      const today = getWibDateRange('hari_ini', nowWib);
      expect(today.start.toISOString()).toBe(nowWib.toISOString());
      expect(today.end.toISOString()).toBe('2026-11-12T16:59:59.999Z'); // 23:59:59.999 WIB

      const tomorrow = getWibDateRange('besok', nowWib);
      expect(tomorrow.start.toISOString()).toBe('2026-11-12T17:00:00.000Z'); // 13 Nov 00:00:00 WIB
      expect(tomorrow.end.toISOString()).toBe('2026-11-13T16:59:59.999Z'); // 13 Nov 23:59:59.999 WIB

      const exact = getWibDateRange('2026-11-20', nowWib);
      expect(exact.start.toISOString()).toBe('2026-11-19T17:00:00.000Z'); // 20 Nov 00:00:00 WIB
      expect(exact.end.toISOString()).toBe('2026-11-20T16:59:59.999Z'); // 20 Nov 23:59:59.999 WIB
    });

    it('menghitung akhir_pekan untuk hari kerja dan saat akhir pekan', () => {
      // Rabu (hari kerja)
      const wednesday = new Date('2026-11-11T03:00:00.000Z'); // 11 Nov 10:00 WIB (Wednesday)
      const weekendFromWed = getWibDateRange('akhir_pekan', wednesday);
      // Sabtu 14 Nov 00:00 WIB -> 13 Nov 17:00 UTC
      expect(weekendFromWed.start.toISOString()).toBe('2026-11-13T17:00:00.000Z');
      // Minggu 15 Nov 23:59:59.999 WIB -> 15 Nov 16:59:59.999 UTC
      expect(weekendFromWed.end.toISOString()).toBe('2026-11-15T16:59:59.999Z');

      // Sabtu (akhir pekan)
      const saturday = new Date('2026-11-14T05:00:00.000Z'); // 14 Nov 12:00 WIB (Saturday)
      const weekendFromSat = getWibDateRange('akhir_pekan', saturday);
      expect(weekendFromSat.start.toISOString()).toBe(saturday.toISOString());
      expect(weekendFromSat.end.toISOString()).toBe('2026-11-15T16:59:59.999Z');
    });

    it('melempar 422 untuk format tanggal tidak valid atau kalender salah', () => {
      expect(() => getWibDateRange('bukan-tanggal')).toThrow();
      expect(() => getWibDateRange('2026-02-31')).toThrow();
    });
  });

  describe('Validasi Query 422', () => {
    it('menolak sort=terdekat tanpa lat dan lng', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const res = await request(app).get('/api/v1/listings?sort=terdekat');
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('menolak max_km tanpa lat dan lng', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const res = await request(app).get('/api/v1/listings?max_km=10');
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('menolak lat tanpa lng atau sebaliknya', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const res1 = await request(app).get('/api/v1/listings?lat=-7.26');
      expect(res1.status).toBe(422);

      const res2 = await request(app).get('/api/v1/listings?lng=112.75');
      expect(res2.status).toBe(422);
    });

    it('menolak min_harga > max_harga', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const res = await request(app).get(
        '/api/v1/listings?min_harga=500000&max_harga=200000'
      );
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('menolak format tanggal yang tidak dikenali', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const res = await request(app).get('/api/v1/listings?tanggal=minggu_depan');
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('Query Aktif, Kedaluwarsa, Hidden, Banned, dan Tersedia', () => {
    it('hanya menampilkan listing aktif dan mengecualikan kedaluwarsa, dihapus, hidden, dan penjual banned', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = Date.now();

      // Listing 1: Aktif normal
      insertListing(db, { id: 101, harga: 300000 });

      // Listing 2: Kedaluwarsa
      insertListing(db, {
        id: 102,
        waktu_acara: new Date(now - 3600_000).toISOString(),
      });

      // Listing 3: Soft-deleted
      insertListing(db, {
        id: 103,
        deleted_at: new Date(now - 1000).toISOString(),
      });

      // Listing 4: Listing hidden oleh pengelola
      insertListing(db, { id: 104, hidden: true });

      // Listing 5: Penjual dibekukan (seller_id: 3 banned)
      insertListing(db, { id: 105, seller_id: 3 });

      // Listing 6: Event disembunyikan (event_id: 9 hidden)
      insertListing(db, { id: 106, event_id: 9 });

      const res = await request(app).get('/api/v1/listings');
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].id).toBe(101);
      expect(res.body.meta.total).toBe(1);
    });

    it('tersedia=false ikut menampilkan listing terjual tapi tetap tidak menampilkan yang kedaluwarsa', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = Date.now();

      // Listing 1: Masih tersedia
      insertListing(db, { id: 201, jumlah_total: 2, jumlah_terjual: 0 });

      // Listing 2: Sudah habis terjual
      insertListing(db, { id: 202, jumlah_total: 2, jumlah_terjual: 2 });

      // Listing 3: Kedaluwarsa
      insertListing(db, {
        id: 203,
        waktu_acara: new Date(now - 3600_000).toISOString(),
      });

      // Default tersedia=true -> hanya listing 201
      const defaultRes = await request(app).get('/api/v1/listings');
      expect(defaultRes.body.data.map((l) => l.id)).toEqual([201]);

      // tersedia=false -> listing 201 dan 202 (203 tetap tidak muncul)
      const allRes = await request(app).get('/api/v1/listings?tersedia=false');
      expect(allRes.body.data.map((l) => l.id)).toEqual(
        expect.arrayContaining([201, 202])
      );
      expect(allRes.body.data.some((l) => l.id === 203)).toBe(false);
    });
  });

  describe('Pencarian dan Filter (q, category, jenis, tipe, kota, harga, dalam_jam, max_km)', () => {
    it('filter q mencari pada nama event, venue, venue_teks, dan kota', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });

      // Event 7 nama: Nada Senja Live in Surabaya, Venue 3: Grand City Convention Hall
      insertListing(db, { id: 301, event_id: 7, venue_id: 3, kota: 'Surabaya' });
      // Event 8 nama: Midnight Movie Premiere
      insertListing(db, {
        id: 302,
        event_id: 8,
        venue_id: null,
        venue_teks: 'Bioskop XXI Delta',
        kota: 'Sidoarjo',
      });

      const qEvent = await request(app).get('/api/v1/listings?q=senja');
      expect(qEvent.body.data.map((l) => l.id)).toEqual([301]);

      const qVenueTeks = await request(app).get('/api/v1/listings?q=delta');
      expect(qVenueTeks.body.data.map((l) => l.id)).toEqual([302]);

      const qKota = await request(app).get('/api/v1/listings?q=sidoarjo');
      expect(qKota.body.data.map((l) => l.id)).toEqual([302]);
    });

    it('filter category, jenis, tipe, dan kota menyaring dengan tepat', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });

      insertListing(db, {
        id: 401,
        event_id: 7, // kategori: konser-festival
        jenis: 'last_minute',
        tipe: 'digital',
        kota: 'Surabaya',
      });
      insertListing(db, {
        id: 402,
        event_id: 8, // kategori: bioskop
        jenis: 'limited',
        tipe: 'fisik',
        kota: 'Jakarta',
      });

      const catRes = await request(app).get('/api/v1/listings?category=bioskop');
      expect(catRes.body.data.map((l) => l.id)).toEqual([402]);

      const jenisRes = await request(app).get('/api/v1/listings?jenis=last_minute');
      expect(jenisRes.body.data.map((l) => l.id)).toEqual([401]);

      const tipeRes = await request(app).get('/api/v1/listings?tipe=fisik');
      expect(tipeRes.body.data.map((l) => l.id)).toEqual([402]);

      const kotaRes = await request(app).get('/api/v1/listings?kota=Jakarta');
      expect(kotaRes.body.data.map((l) => l.id)).toEqual([402]);
    });

    it('filter rentang harga min_harga dan max_harga', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });

      insertListing(db, { id: 501, harga: 200000 });
      insertListing(db, { id: 502, harga: 450000 });
      insertListing(db, { id: 503, harga: 800000 });

      const res = await request(app).get(
        '/api/v1/listings?min_harga=300000&max_harga=500000'
      );
      expect(res.body.data.map((l) => l.id)).toEqual([502]);
    });

    it('filter dalam_jam menyaring acara yang dimulai dalam rentang jam tersebut', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = Date.now();

      // Listing 1: 5 jam lagi
      insertListing(db, {
        id: 601,
        waktu_acara: new Date(now + 5 * 3600_000).toISOString(),
      });
      // Listing 2: 30 jam lagi
      insertListing(db, {
        id: 602,
        waktu_acara: new Date(now + 30 * 3600_000).toISOString(),
      });

      const res = await request(app).get('/api/v1/listings?dalam_jam=12');
      expect(res.body.data.map((l) => l.id)).toEqual([601]);
    });

    it('filter max_km dan jarak Haversine menyaring dalam radius dan mengecualikan tanpa koordinat', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });

      // User di Balai Pemuda Surabaya: -7.263, 112.745
      const userLat = -7.263;
      const userLng = 112.745;

      // Listing 1: Grand City (jarak ~0.7 km)
      insertListing(db, {
        id: 701,
        ref_lat: -7.262,
        ref_lng: 112.751,
      });

      // Listing 2: GBK Jakarta (jarak > 600 km)
      insertListing(db, {
        id: 702,
        ref_lat: -6.218,
        ref_lng: 106.802,
      });

      // Listing 3: Tanpa koordinat
      insertListing(db, {
        id: 703,
        ref_lat: null,
        ref_lng: null,
      });

      const res = await request(app).get(
        `/api/v1/listings?lat=${userLat}&lng=${userLng}&max_km=10`
      );
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].id).toBe(701);
      expect(res.body.data[0].jarak_km).toBeLessThan(5);
    });
  });

  describe('Urutan (sort) dan Pagination', () => {
    it('mengurutkan berdasarkan termurah, segera, terbaru, dan terdekat', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = Date.now();

      insertListing(db, {
        id: 801,
        harga: 500000,
        waktu_acara: new Date(now + 10 * 3600_000).toISOString(),
        created_at: new Date(now - 1000).toISOString(),
        ref_lat: -7.262,
        ref_lng: 112.751, // Dekat Surabaya (~0.7 km)
      });
      insertListing(db, {
        id: 802,
        harga: 200000,
        waktu_acara: new Date(now + 50 * 3600_000).toISOString(),
        created_at: new Date(now - 5000).toISOString(),
        ref_lat: -7.228,
        ref_lng: 112.632, // Sedang Surabaya (~13 km)
      });
      insertListing(db, {
        id: 803,
        harga: 800000,
        waktu_acara: new Date(now + 2 * 3600_000).toISOString(),
        created_at: new Date(now - 2000).toISOString(),
        ref_lat: -6.218,
        ref_lng: 106.802, // Jauh (Jakarta)
      });

      // Termurah
      const termurahRes = await request(app).get('/api/v1/listings?sort=termurah');
      expect(termurahRes.body.data.map((l) => l.id)).toEqual([802, 801, 803]);

      // Segera (waktu acara paling awal)
      const segeraRes = await request(app).get('/api/v1/listings?sort=segera');
      expect(segeraRes.body.data.map((l) => l.id)).toEqual([803, 801, 802]);

      // Terbaru (created_at descending)
      const terbaruRes = await request(app).get('/api/v1/listings?sort=terbaru');
      expect(terbaruRes.body.data.map((l) => l.id)).toEqual([801, 803, 802]);

      // Terdekat dengan user Surabaya (-7.263, 112.745)
      const terdekatRes = await request(app).get(
        '/api/v1/listings?sort=terdekat&lat=-7.263&lng=112.745'
      );
      expect(terdekatRes.body.data.map((l) => l.id)).toEqual([801, 802, 803]);
    });

    it('mendukung pagination page dan limit dengan meta total', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });

      for (let i = 1; i <= 5; i++) {
        insertListing(db, { id: 900 + i, harga: 100000 * i });
      }

      const page1 = await request(app).get(
        '/api/v1/listings?page=1&limit=2&sort=termurah'
      );
      expect(page1.status).toBe(200);
      expect(page1.body.data.map((l) => l.id)).toEqual([901, 902]);
      expect(page1.body.meta).toEqual({ page: 1, limit: 2, total: 5 });

      const page2 = await request(app).get(
        '/api/v1/listings?page=2&limit=2&sort=termurah'
      );
      expect(page2.status).toBe(200);
      expect(page2.body.data.map((l) => l.id)).toEqual([903, 904]);
      expect(page2.body.meta).toEqual({ page: 2, limit: 2, total: 5 });
    });

    it('menampilkan status is_favorite jika diakses oleh pengguna terautentikasi', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const user = db.users[0];
      const token = makeToken(user);

      insertListing(db, { id: 950 });
      db.favorites.push({ user_id: user.id, listing_id: 950 });

      // Akses publik (tanpa token) -> is_favorite: false
      const anonRes = await request(app).get('/api/v1/listings');
      expect(anonRes.body.data.find((l) => l.id === 950).is_favorite).toBe(false);

      // Akses dengan token -> is_favorite: true
      const authRes = await request(app)
        .get('/api/v1/listings')
        .set('Authorization', `Bearer ${token}`);
      expect(authRes.body.data.find((l) => l.id === 950).is_favorite).toBe(true);
    });
  });
});

