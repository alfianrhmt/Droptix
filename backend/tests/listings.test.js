'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/index');
const { getJwtSecret } = require('../src/middleware/auth');
const { haversineKm, getWibDateRange } = require('../src/routes/listings');
const {
  RELEVANCE_WEIGHTS,
  getNormalizedWeights,
  calculateSJarak,
  calculateSWaktu,
  calculateSHarga,
  computeRelevanceScore,
  buildRelevanceSqlOrder,
} = require('../src/config/relevance');

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

      if (q.startsWith('INSERT INTO favorites')) {
        const [userId, listingId] = params;
        const exists = favorites.some(
          (f) => f.user_id === userId && f.listing_id === listingId
        );
        if (!exists) {
          favorites.push({
            user_id: userId,
            listing_id: listingId,
            created_at: new Date().toISOString(),
          });
        }
        return { rows: [] };
      }

      if (q.startsWith('DELETE FROM favorites')) {
        const [userId, listingId] = params;
        const idx = favorites.findIndex(
          (f) => f.user_id === userId && f.listing_id === listingId
        );
        if (idx !== -1) {
          favorites.splice(idx, 1);
        }
        return { rows: [] };
      }

      if (
        q.includes('FROM favorites f') &&
        q.includes('JOIN listings l ON l.id = f.listing_id')
      ) {
        const userId = params[0];
        const userFavs = favorites
          .filter((f) => f.user_id === userId)
          .sort(
            (a, b) =>
              new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          );

        const favListings = [];
        for (const fav of userFavs) {
          const l = listings.find((x) => x.id === fav.listing_id);
          if (!l || l.deleted_at || l.hidden) continue;
          const seller = users.find((u) => u.id === l.seller_id);
          if (!seller || seller.banned_at) continue;
          favListings.push(l);
        }

        if (q.startsWith('SELECT count(*)::int AS total')) {
          return { rows: [{ total: favListings.length }] };
        }

        const limit = params[1] || 20;
        const offset = params[2] || 0;
        const page = favListings
          .slice(offset, offset + limit)
          .map((l) => hydrateListing(l, userId));
        return { rows: page };
      }

      if (q.startsWith('SELECT l.id, l.deleted_at, l.hidden, u.banned_at')) {
        const l = listings.find((x) => x.id === params[0]);
        if (!l) return { rows: [] };
        const u = users.find((x) => x.id === l.seller_id);
        return {
          rows: [
            {
              id: l.id,
              deleted_at: l.deleted_at,
              hidden: l.hidden,
              banned_at: u ? u.banned_at : null,
            },
          ],
        };
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
        } else if (q.includes('ORDER BY l.created_at DESC')) {
          filtered.sort(
            (a, b) =>
              new Date(b.created_at).getTime() - new Date(a.created_at).getTime() ||
              b.id - a.id
          );
        } else {
          // Relevan (BR-5)
          const matchRelLat = /radians\(l\.ref_lat - \$(\d+)\)/.exec(q);
          const matchRelLng = /radians\(l\.ref_lng - \$(\d+)\)/.exec(q);
          const hasUserLocation = Boolean(matchRelLat && matchRelLng);
          const sLat = matchRelLat ? params[parseInt(matchRelLat[1], 10) - 1] : null;
          const sLng = matchRelLng ? params[parseInt(matchRelLng[1], 10) - 1] : null;

          function getMinEventPrice(eventId) {
            const activeListings = listings.filter((l) => {
              if (l.event_id !== eventId) return false;
              if (l.deleted_at || l.hidden) return false;
              if (new Date(l.waktu_acara).getTime() <= Date.now()) return false;
              if (l.jumlah_total - l.jumlah_terjual <= 0) return false;
              const seller = users.find((u) => u.id === l.seller_id);
              if (!seller || seller.banned_at) return false;
              return true;
            });
            if (activeListings.length === 0) return null;
            return Math.min(...activeListings.map((l) => l.harga));
          }

          filtered.sort((a, b) => {
            const distA = hasUserLocation && a.ref_lat != null && a.ref_lng != null
              ? haversineKm(sLat, sLng, a.ref_lat, a.ref_lng)
              : null;
            const distB = hasUserLocation && b.ref_lat != null && b.ref_lng != null
              ? haversineKm(sLat, sLng, b.ref_lat, b.ref_lng)
              : null;

            const scoreA = computeRelevanceScore({
              jenis: a.jenis,
              harga: a.harga,
              hargaMinEvent: getMinEventPrice(a.event_id),
              waktuAcara: a.waktu_acara,
              jarakKm: distA,
              hasUserLocation,
            }).skor;

            const scoreB = computeRelevanceScore({
              jenis: b.jenis,
              harga: b.harga,
              hargaMinEvent: getMinEventPrice(b.event_id),
              waktuAcara: b.waktu_acara,
              jarakKm: distB,
              hasUserLocation,
            }).skor;

            if (scoreB !== scoreA) {
              return scoreB - scoreA;
            }
            const timeA = new Date(a.waktu_acara).getTime();
            const timeB = new Date(b.waktu_acara).getTime();
            if (timeA !== timeB) {
              return timeA - timeB;
            }
            return b.id - a.id;
          });
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

describe('Skor relevansi BR-5 dan sort=relevan (T4.2)', () => {
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

  it('bobot tersimpan di satu berkas konfigurasi dengan nilai BR-5', () => {
    expect(RELEVANCE_WEIGHTS).toEqual({
      last_minute: { jarak: 0.45, waktu: 0.35, harga: 0.20 },
      limited: { jarak: 0.15, waktu: 0.25, harga: 0.60 },
    });
  });

  it('normalisasi ulang bobot tanpa lokasi menghasilkan total 1.0', () => {
    const normLm = getNormalizedWeights('last_minute', false);
    expect(normLm.jarak).toBe(0);
    expect(normLm.waktu).toBeCloseTo(0.35 / 0.55, 5);
    expect(normLm.harga).toBeCloseTo(0.20 / 0.55, 5);
    expect(normLm.waktu + normLm.harga).toBeCloseTo(1.0, 5);

    const normLim = getNormalizedWeights('limited', false);
    expect(normLim.jarak).toBe(0);
    expect(normLim.waktu).toBeCloseTo(0.25 / 0.85, 5);
    expect(normLim.harga).toBeCloseTo(0.60 / 0.85, 5);
    expect(normLim.waktu + normLim.harga).toBeCloseTo(1.0, 5);
  });

  it('menghitung komponen S_jarak, S_waktu, dan S_harga dengan benar', () => {
    expect(calculateSJarak(0)).toBe(1.0);
    expect(calculateSJarak(10)).toBe(0.5);
    expect(calculateSJarak(20)).toBe(0.0);
    expect(calculateSJarak(50)).toBe(0.0);
    expect(calculateSJarak(null)).toBe(0.0);

    const now = new Date('2026-11-12T10:00:00Z');
    expect(calculateSWaktu('2026-11-12T10:00:00Z', now)).toBe(1.0); // 0 jam
    expect(calculateSWaktu('2026-11-13T10:00:00Z', now)).toBe(0.5); // 24 jam
    expect(calculateSWaktu('2026-11-14T10:00:00Z', now)).toBe(0.0); // 48 jam
    expect(calculateSWaktu('2026-11-15T10:00:00Z', now)).toBe(0.0); // > 48 jam

    expect(calculateSHarga(300000, 300000)).toBe(1.0);
    expect(calculateSHarga(600000, 300000)).toBe(0.5);
    expect(calculateSHarga(1000000, 200000)).toBe(0.2);
    expect(calculateSHarga(500000, null)).toBe(1.0); // fallback
  });

  it('computeRelevanceScore menghitung skor akurat dengan atau tanpa lokasi', () => {
    const now = new Date('2026-11-12T10:00:00Z');
    const acara = '2026-11-13T10:00:00Z'; // sisa 24 jam -> S_waktu = 0.5

    // Last-minute dengan lokasi, jarak 10km (S_jarak=0.5), harga 600k vs min 300k (S_harga=0.5)
    // skor = 0.45 * 0.5 + 0.35 * 0.5 + 0.20 * 0.5 = 0.5
    const lmWithLoc = computeRelevanceScore({
      jenis: 'last_minute',
      harga: 600000,
      hargaMinEvent: 300000,
      waktuAcara: acara,
      jarakKm: 10,
      hasUserLocation: true,
      now,
    });
    expect(lmWithLoc.skor).toBeCloseTo(0.5, 4);

    // Tanpa lokasi: bobot dinormalisasi
    // w_waktu = 0.35/0.55, w_harga = 0.20/0.55
    // skor = (0.35/0.55)*0.5 + (0.20/0.55)*0.5 = 0.5
    const lmNoLoc = computeRelevanceScore({
      jenis: 'last_minute',
      harga: 600000,
      hargaMinEvent: 300000,
      waktuAcara: acara,
      jarakKm: 10,
      hasUserLocation: false,
      now,
    });
    expect(lmNoLoc.skor).toBeCloseTo(0.5, 4);

    // Dengan lokasi tetapi listing tanpa koordinat acuan -> S_jarak = 0
    const lmNoRef = computeRelevanceScore({
      jenis: 'last_minute',
      harga: 300000,
      hargaMinEvent: 300000,
      waktuAcara: acara,
      jarakKm: null,
      hasUserLocation: true,
      now,
    });
    // skor = 0.45 * 0 + 0.35 * 0.5 + 0.20 * 1.0 = 0.175 + 0.20 = 0.375
    expect(lmNoRef.skor).toBeCloseTo(0.375, 4);
  });

  it('GET /listings default sort=relevan memprioritaskan jarak untuk last_minute dan harga untuk limited', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const now = Date.now();

    // User di Surabaya (-7.263, 112.745)
    // Event 7 (Konser Nada Senja)
    // Listing LM-Dekat: jarak ~0.7 km (S_jarak ~0.965), harga mahal 500k, waktu 12 jam
    insertListing(db, {
      id: 1001,
      jenis: 'last_minute',
      harga: 500000,
      waktu_acara: new Date(now + 12 * 3600_000).toISOString(),
      ref_lat: -7.262,
      ref_lng: 112.751, // dekat (~0.7 km)
    });

    // Listing LM-Jauh: jarak ~600 km (S_jarak 0), harga lebih murah 250k, waktu 12 jam
    insertListing(db, {
      id: 1002,
      jenis: 'last_minute',
      harga: 250000,
      waktu_acara: new Date(now + 12 * 3600_000).toISOString(),
      ref_lat: -6.218,
      ref_lng: 106.802, // jauh (Jakarta)
    });

    // Untuk Last-Minute: bobot jarak (0.45) jauh lebih besar daripada harga (0.20).
    // LM-Dekat harus berada di atas LM-Jauh saat ada lokasi user.
    const resWithLoc = await request(app).get(
      '/api/v1/listings?lat=-7.263&lng=112.745'
    );
    expect(resWithLoc.body.data.map((l) => l.id)).toEqual([1001, 1002]);

    // Saat lokasi dibuang (tanpa lat & lng):
    // Komponen jarak hilang, harga LM-Jauh (250k vs min 250k = 1.0) menang atas LM-Dekat (500k = 0.5)
    const resNoLoc = await request(app).get('/api/v1/listings');
    expect(resNoLoc.body.data.map((l) => l.id)).toEqual([1002, 1001]);
  });

  it('tie-breaking pada skor relevansi yang sama diurutkan waktu_acara naik lalu id turun', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const now = Date.now();

    // Dua listing dengan jenis, harga, dan jarak sama, tetapi waktu_acara berbeda
    insertListing(db, {
      id: 1101,
      jenis: 'limited',
      harga: 300000,
      waktu_acara: new Date(now + 40 * 3600_000).toISOString(), // lebih lama
      ref_lat: -7.262,
      ref_lng: 112.751,
    });
    insertListing(db, {
      id: 1102,
      jenis: 'limited',
      harga: 300000,
      waktu_acara: new Date(now + 10 * 3600_000).toISOString(), // lebih cepat (S_waktu lebih tinggi)
      ref_lat: -7.262,
      ref_lng: 112.751,
    });

    const res = await request(app).get(
      '/api/v1/listings?lat=-7.263&lng=112.745'
    );
    expect(res.body.data.map((l) => l.id)).toEqual([1102, 1101]);
  });
});

describe('T4.6 Tes Verifikasi: Filter, Urutan, Kedaluwarsa, dan Skor Relevansi (Skenario Uji 5 & 8)', () => {
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

  describe('Skenario Uji 5: Pembeli mencari dengan filter Hari ini + jenis Last-Minute dan urutan Relevan berubah saat lokasi berbeda', () => {
    it('mengubah urutan Relevan secara wajar saat lokasi pembeli diganti antara Surabaya dan Jakarta', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = new Date();

      const { end } = getWibDateRange('hari_ini', now);
      const eventTimeMs = Math.min(now.getTime() + 4 * 3600_000, end.getTime() - 1000);
      const waktuAcaraHariIni = new Date(eventTimeMs).toISOString();

      // Listing 1: Venue di Surabaya (-7.262, 112.751), harga 400.000, Last-Minute
      insertListing(db, {
        id: 2001,
        event_id: 7,
        jenis: 'last_minute',
        kota: 'Surabaya',
        harga: 400000,
        waktu_acara: waktuAcaraHariIni,
        ref_lat: -7.262,
        ref_lng: 112.751,
      });

      // Listing 2: Venue di Jakarta (-6.218, 106.802), harga 300.000 (lebih murah), Last-Minute
      insertListing(db, {
        id: 2002,
        event_id: 7,
        jenis: 'last_minute',
        kota: 'Jakarta',
        harga: 300000,
        waktu_acara: waktuAcaraHariIni,
        ref_lat: -6.218,
        ref_lng: 106.802,
      });

      // 1. Pembeli berada di Surabaya (-7.263, 112.745):
      // Listing 2001 dekat (~0.7 km, S_jarak ~0.965), Listing 2002 jauh (>600 km, S_jarak 0.0)
      // Pada last_minute, bobot jarak 0.45, sehingga Listing Surabaya menempati posisi #1
      const resSby = await request(app).get(
        '/api/v1/listings?tanggal=hari_ini&jenis=last_minute&lat=-7.263&lng=112.745&sort=relevan'
      );
      expect(resSby.status).toBe(200);
      expect(resSby.body.data.length).toBe(2);
      expect(resSby.body.data.map((l) => l.id)).toEqual([2001, 2002]);

      // 2. Pembeli berada di Jakarta (-6.210, 106.810):
      // Listing 2002 dekat (~1 km, S_jarak ~0.95) dan harga lebih murah (300k vs 400k)
      // Listing 2001 jauh (>600 km, S_jarak 0.0)
      // Urutan berubah: Listing Jakarta menempati posisi #1
      const resJkt = await request(app).get(
        '/api/v1/listings?tanggal=hari_ini&jenis=last_minute&lat=-6.210&lng=106.810&sort=relevan'
      );
      expect(resJkt.status).toBe(200);
      expect(resJkt.body.data.length).toBe(2);
      expect(resJkt.body.data.map((l) => l.id)).toEqual([2002, 2001]);
    });
  });

  describe('Dua listing dengan jarak berbeda: perbedaan prioritas bobot per jenis (Last-Minute vs Limited)', () => {
    it('memprioritaskan jarak untuk last_minute (bobot jarak 0.45) dan memprioritaskan harga untuk limited (bobot harga 0.60)', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = Date.now();

      // Skenario Last-Minute:
      // Listing Dekat-Mahal: Jarak ~2 km dari user, harga 500k
      insertListing(db, {
        id: 2101,
        event_id: 7,
        jenis: 'last_minute',
        harga: 500000,
        waktu_acara: new Date(now + 12 * 3600_000).toISOString(),
        ref_lat: -7.262,
        ref_lng: 112.751,
      });

      // Listing Jauh-Murah: Jarak ~18 km dari user, harga 250k (lebih murah)
      insertListing(db, {
        id: 2102,
        event_id: 7,
        jenis: 'last_minute',
        harga: 250000,
        waktu_acara: new Date(now + 12 * 3600_000).toISOString(),
        ref_lat: -7.380,
        ref_lng: 112.780, // ~14-18 km
      });

      // Untuk last_minute, jarak dekat (2101) menang atas harga murah (2102)
      const resLm = await request(app).get(
        '/api/v1/listings?jenis=last_minute&lat=-7.263&lng=112.745&sort=relevan'
      );
      expect(resLm.body.data.map((l) => l.id)).toEqual([2101, 2102]);

      // Skenario Limited pada event 7:
      // Listing Dekat-Mahal: Jarak ~2 km, harga 800k (event min 400k -> S_harga 0.5)
      insertListing(db, {
        id: 2201,
        event_id: 7,
        jenis: 'limited',
        harga: 800000,
        waktu_acara: new Date(now + 30 * 3600_000).toISOString(),
        ref_lat: -7.262,
        ref_lng: 112.751,
      });

      // Listing Jauh-Murah: Jarak ~18 km, harga 400k (event min 400k -> S_harga 1.0)
      insertListing(db, {
        id: 2202,
        event_id: 7,
        jenis: 'limited',
        harga: 400000,
        waktu_acara: new Date(now + 30 * 3600_000).toISOString(),
        ref_lat: -7.380,
        ref_lng: 112.780,
      });

      // Untuk limited, bobot harga adalah 0.60 (sangat dominan dibanding jarak 0.15)
      // Sehingga Listing Murah (2202) menang atas Listing Dekat (2201)
      const resLim = await request(app).get(
        '/api/v1/listings?category=konser-festival&jenis=limited&lat=-7.263&lng=112.745&sort=relevan'
      );
      const limitedIds = resLim.body.data
        .map((l) => l.id)
        .filter((id) => id === 2201 || id === 2202);
      expect(limitedIds).toEqual([2202, 2201]);
    });
  });

  describe('Skenario Uji 8: Listing yang waktu acaranya lewat otomatis hilang dari pencarian', () => {
    it('mengecualikan listing yang waktu acaranya sudah lewat dari hasil GET /listings', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = Date.now();

      // Listing 1: Aktif, waktu acara 2 jam ke depan
      insertListing(db, {
        id: 3001,
        event_id: 7,
        waktu_acara: new Date(now + 2 * 3600_000).toISOString(),
      });

      // Listing 2: Kedaluwarsa, waktu acara 1 detik lalu
      insertListing(db, {
        id: 3002,
        event_id: 7,
        waktu_acara: new Date(now - 1000).toISOString(),
      });

      // Listing 3: Kedaluwarsa, waktu acara 1 hari lalu
      insertListing(db, {
        id: 3003,
        event_id: 7,
        waktu_acara: new Date(now - 86400_000).toISOString(),
      });

      // 1. Pencarian umum
      const resAll = await request(app).get('/api/v1/listings');
      expect(resAll.body.data.some((l) => l.id === 3001)).toBe(true);
      expect(resAll.body.data.some((l) => l.id === 3002)).toBe(false);
      expect(resAll.body.data.some((l) => l.id === 3003)).toBe(false);

      // 2. Pencarian dengan filter kata kunci
      const resQ = await request(app).get('/api/v1/listings?q=Nada');
      expect(resQ.body.data.some((l) => l.id === 3001)).toBe(true);
      expect(resQ.body.data.some((l) => l.id === 3002)).toBe(false);

      // 3. Pencarian dengan tersedia=false (tetap tidak menampilkan yang sudah lewat)
      const resNotAvailable = await request(app).get('/api/v1/listings?tersedia=false');
      expect(resNotAvailable.body.data.some((l) => l.id === 3002)).toBe(false);
      expect(resNotAvailable.body.data.some((l) => l.id === 3003)).toBe(false);

      // 4. Detail listing kedaluwarsa tetap bisa dibuka dengan status 'kedaluwarsa'
      const resDetail = await request(app).get('/api/v1/listings/3002');
      expect(resDetail.status).toBe(200);
      expect(resDetail.body.data.status).toBe('kedaluwarsa');
    });
  });

  describe('Kombinasi Filter dan Urutan', () => {
    it('berhasil memfilter kategori, tipe, rentang harga, dan mengurutkan berdasarkan termurah', async () => {
      const db = createListingsMockDb();
      const app = createApp({ db, useRateLimit: false });
      const now = Date.now();

      insertListing(db, {
        id: 4001,
        event_id: 7,
        tipe: 'digital',
        harga: 500000,
        waktu_acara: new Date(now + 24 * 3600_000).toISOString(),
      });

      insertListing(db, {
        id: 4002,
        event_id: 7,
        tipe: 'digital',
        harga: 300000,
        waktu_acara: new Date(now + 24 * 3600_000).toISOString(),
      });

      insertListing(db, {
        id: 4003,
        event_id: 7,
        tipe: 'fisik',
        harga: 250000,
        waktu_acara: new Date(now + 24 * 3600_000).toISOString(),
      });

      const res = await request(app).get(
        '/api/v1/listings?category=konser-festival&tipe=digital&min_harga=200000&max_harga=600000&sort=termurah'
      );
      expect(res.status).toBe(200);
      expect(res.body.data.map((l) => l.id)).toEqual([4002, 4001]);
    });
  });
});

describe('T5.1 Backend: POST/DELETE /listings/:id/favorite & GET /me/favorites', () => {
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

  it('memerlukan autentikasi untuk memfavoritkan atau menghapus favorit', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });

    const postRes = await request(app).post('/api/v1/listings/1/favorite');
    expect(postRes.status).toBe(401);

    const delRes = await request(app).delete('/api/v1/listings/1/favorite');
    expect(delRes.status).toBe(401);

    const getRes = await request(app).get('/api/v1/me/favorites');
    expect(getRes.status).toBe(401);
  });

  it('memvalidasi format ID listing pada URL parameter', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const token = makeToken(db.users[0]);

    const postRes = await request(app)
      .post('/api/v1/listings/abc/favorite')
      .set('Authorization', `Bearer ${token}`);
    expect(postRes.status).toBe(422);

    const delRes = await request(app)
      .delete('/api/v1/listings/-1/favorite')
      .set('Authorization', `Bearer ${token}`);
    expect(delRes.status).toBe(422);
  });

  it('mengembalikan 404 jika listing yang difavoritkan tidak ditemukan atau dihapus', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const token = makeToken(db.users[0]);

    const notFoundRes = await request(app)
      .post('/api/v1/listings/9999/favorite')
      .set('Authorization', `Bearer ${token}`);
    expect(notFoundRes.status).toBe(404);

    insertListing(db, { id: 5001, deleted_at: new Date().toISOString() });
    const deletedRes = await request(app)
      .post('/api/v1/listings/5001/favorite')
      .set('Authorization', `Bearer ${token}`);
    expect(deletedRes.status).toBe(404);
  });

  it('berhasil memfavoritkan listing (idempoten) dan mencerminkan is_favorite=true pada detail', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const token = makeToken(db.users[0]);

    insertListing(db, { id: 5002 });

    // 1. Tambah favorit
    const favRes = await request(app)
      .post('/api/v1/listings/5002/favorite')
      .set('Authorization', `Bearer ${token}`);
    expect(favRes.status).toBe(200);
    expect(favRes.body.data).toEqual({ is_favorite: true });

    // 2. Idempoten: panggil ulang
    const favResRepeat = await request(app)
      .post('/api/v1/listings/5002/favorite')
      .set('Authorization', `Bearer ${token}`);
    expect(favResRepeat.status).toBe(200);
    expect(favResRepeat.body.data).toEqual({ is_favorite: true });

    // 3. Detail listing sekarang berstatus is_favorite=true
    const detailRes = await request(app)
      .get('/api/v1/listings/5002')
      .set('Authorization', `Bearer ${token}`);
    expect(detailRes.status).toBe(200);
    expect(detailRes.body.data.is_favorite).toBe(true);

    // Tanpa token login, detail listing menampilkan is_favorite=false
    const guestDetailRes = await request(app).get('/api/v1/listings/5002');
    expect(guestDetailRes.body.data.is_favorite).toBe(false);
  });

  it('berhasil menghapus favorit dan mencerminkan is_favorite=false', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const token = makeToken(db.users[0]);

    insertListing(db, { id: 5003 });
    db.favorites.push({ user_id: db.users[0].id, listing_id: 5003, created_at: new Date().toISOString() });

    const delRes = await request(app)
      .delete('/api/v1/listings/5003/favorite')
      .set('Authorization', `Bearer ${token}`);
    expect(delRes.status).toBe(200);
    expect(delRes.body.data).toEqual({ is_favorite: false });

    // Detail mencerminkan is_favorite=false
    const detailRes = await request(app)
      .get('/api/v1/listings/5003')
      .set('Authorization', `Bearer ${token}`);
    expect(detailRes.body.data.is_favorite).toBe(false);
  });

  it('GET /me/favorites menampilkan daftar favorit terurut terbaru dulu beserta jarak_km dan status', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const user = db.users[0];
    const token = makeToken(user);
    const now = Date.now();

    // Listing 1: Masih tersedia
    insertListing(db, {
      id: 5010,
      harga: 350000,
      ref_lat: -7.262,
      ref_lng: 112.751,
    });

    // Listing 2: Sudah terjual
    insertListing(db, {
      id: 5020,
      harga: 500000,
      jumlah_total: 2,
      jumlah_terjual: 2,
      ref_lat: -7.262,
      ref_lng: 112.751,
    });

    // Listing 3: Kedaluwarsa
    insertListing(db, {
      id: 5030,
      harga: 200000,
      waktu_acara: new Date(now - 3600_000).toISOString(),
      ref_lat: -7.262,
      ref_lng: 112.751,
    });

    // Masukkan ke favorit dengan waktu berbeda: 5010 dulu, lalu 5020, lalu 5030 (paling baru)
    db.favorites.push({ user_id: user.id, listing_id: 5010, created_at: new Date(now - 3000).toISOString() });
    db.favorites.push({ user_id: user.id, listing_id: 5020, created_at: new Date(now - 2000).toISOString() });
    db.favorites.push({ user_id: user.id, listing_id: 5030, created_at: new Date(now - 1000).toISOString() });

    const res = await request(app)
      .get('/api/v1/me/favorites?lat=-7.263&lng=112.745&limit=10')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(3);
    // Urutan favorit terbaru dulu: 5030, 5020, 5010
    expect(res.body.data.map((l) => l.id)).toEqual([5030, 5020, 5010]);
    expect(res.body.meta.total).toBe(3);

    // Verifikasi setiap item memiliki is_favorite=true dan jarak terhitung
    for (const card of res.body.data) {
      expect(card.is_favorite).toBe(true);
      expect(card.jarak_km).toBeCloseTo(0.7, 1);
    }

    // Status masing-masing sesuai kondisi
    expect(res.body.data.find((l) => l.id === 5010).status).toBe('tersedia');
    expect(res.body.data.find((l) => l.id === 5020).status).toBe('terjual');
    expect(res.body.data.find((l) => l.id === 5030).status).toBe('kedaluwarsa');
  });

  it('GET /me/favorites mendukung pagination page dan limit', async () => {
    const db = createListingsMockDb();
    const app = createApp({ db, useRateLimit: false });
    const user = db.users[0];
    const token = makeToken(user);
    const now = Date.now();

    for (let i = 1; i <= 5; i++) {
      insertListing(db, { id: 6000 + i });
      db.favorites.push({
        user_id: user.id,
        listing_id: 6000 + i,
        created_at: new Date(now + i * 1000).toISOString(),
      });
    }

    // Page 1, limit 2 -> item 6005, 6004
    const page1Res = await request(app)
      .get('/api/v1/me/favorites?page=1&limit=2')
      .set('Authorization', `Bearer ${token}`);
    expect(page1Res.status).toBe(200);
    expect(page1Res.body.data.map((l) => l.id)).toEqual([6005, 6004]);
    expect(page1Res.body.meta).toEqual({
      page: 1,
      limit: 2,
      total: 5,
    });

    // Page 2, limit 2 -> item 6003, 6002
    const page2Res = await request(app)
      .get('/api/v1/me/favorites?page=2&limit=2')
      .set('Authorization', `Bearer ${token}`);
    expect(page2Res.status).toBe(200);
    expect(page2Res.body.data.map((l) => l.id)).toEqual([6003, 6002]);
  });
});

