'use strict';

const request = require('supertest');
const { createApp } = require('../src/index');
const { haversineKm } = require('../src/routes/listings');

function createTrendingMockDb() {
  const now = Date.now();
  const users = [
    { id: 1, nama: 'User 1', email: 'u1@example.com', banned_at: null },
    {
      id: 2,
      nama: 'Banned User',
      email: 'banned@example.com',
      banned_at: new Date(now - 86400_000).toISOString(),
    },
  ];
  const categories = [
    { id: 1, slug: 'konser-festival', nama: 'Konser & Festival', urutan: 1 },
    { id: 2, slug: 'bioskop', nama: 'Bioskop', urutan: 2 },
    { id: 3, slug: 'olahraga', nama: 'Olahraga', urutan: 3 },
    { id: 4, slug: 'wisata', nama: 'Wisata', urutan: 4 },
    { id: 5, slug: 'hiburan-lain', nama: 'Lainnya', urutan: 5 },
  ];
  const venues = [
    { id: 1, nama: 'Grand City Hall', kota: 'Surabaya', lat: -7.262, lng: 112.751 },
    { id: 2, nama: 'GBK Senayan', kota: 'Jakarta', lat: -6.218, lng: 106.802 },
  ];
  const events = [];
  const listings = [];
  const conversations = [];

  return {
    users,
    categories,
    venues,
    events,
    listings,
    conversations,
    query: async (sql, params = []) => {
      const q = sql.trim();

      if (q.includes('FROM event_scores')) {
        // Kategori acara (konser-festival, olahraga, hiburan-lain)
        const eventCategories = new Set(['konser-festival', 'olahraga', 'hiburan-lain']);
        const sevenDaysAgo = Date.now() - 7 * 86400_000;

        const results = [];
        for (const cat of categories) {
          if (!eventCategories.has(cat.slug)) continue;

          const catEvents = events.filter((e) => e.category_id === cat.id && !e.hidden);
          let bestEvent = null;
          let bestScore = -1;

          for (const ev of catEvents) {
            const activeListings = listings.filter((l) => {
              if (l.event_id !== ev.id) return false;
              if (l.deleted_at || l.hidden) return false;
              if (new Date(l.waktu_acara).getTime() <= Date.now()) return false;
              if (l.jumlah_total - l.jumlah_terjual <= 0) return false;
              const seller = users.find((u) => u.id === l.seller_id);
              if (!seller || seller.banned_at) return false;
              return true;
            });

            if (activeListings.length === 0) continue;

            const convs7d = conversations.filter((c) => {
              const matchesListing = activeListings.some((l) => l.id === c.listing_id);
              if (!matchesListing) return false;
              return new Date(c.created_at).getTime() >= sevenDaysAgo;
            }).length;

            const score = activeListings.length + 0.5 * convs7d;
            if (score > bestScore) {
              bestScore = score;
              bestEvent = {
                id: ev.id,
                category_id: ev.category_id,
                nama: ev.nama,
                poster_url: ev.poster_url ?? null,
                category_slug: cat.slug,
                category_urutan: cat.urutan,
                skor_event: score,
              };
            }
          }

          if (bestEvent) {
            results.push(bestEvent);
          }
        }

        return { rows: results };
      }

      if (q.includes('FROM ranked_listings')) {
        // Kategori terdekat (bioskop, wisata)
        const nearestCategories = new Set(['bioskop', 'wisata']);
        const userLat = params[0];
        const userLng = params[1];

        const results = [];
        for (const cat of categories) {
          if (!nearestCategories.has(cat.slug)) continue;

          const activeListings = listings.filter((l) => {
            const ev = events.find((e) => e.id === l.event_id);
            if (!ev || ev.category_id !== cat.id || ev.hidden) return false;
            if (l.deleted_at || l.hidden) return false;
            if (new Date(l.waktu_acara).getTime() <= Date.now()) return false;
            if (l.jumlah_total - l.jumlah_terjual <= 0) return false;
            const seller = users.find((u) => u.id === l.seller_id);
            if (!seller || seller.banned_at) return false;
            if (l.ref_lat == null || l.ref_lng == null) return false;
            return true;
          });

          if (activeListings.length === 0) continue;

          activeListings.sort((a, b) => {
            const distA = haversineKm(userLat, userLng, a.ref_lat, a.ref_lng) ?? 999999;
            const distB = haversineKm(userLat, userLng, b.ref_lat, b.ref_lng) ?? 999999;
            if (distA !== distB) return distA - distB;
            const timeA = new Date(a.waktu_acara).getTime();
            const timeB = new Date(b.waktu_acara).getTime();
            if (timeA !== timeB) return timeA - timeB;
            return b.id - a.id;
          });

          const nearestListing = activeListings[0];
          const ev = events.find((e) => e.id === nearestListing.event_id);
          const v = nearestListing.venue_id
            ? venues.find((vn) => vn.id === nearestListing.venue_id)
            : null;
          results.push({
            ...nearestListing,
            event_nama: ev.nama,
            event_poster_url: ev.poster_url ?? null,
            category_id: cat.id,
            category_slug: cat.slug,
            category_nama: cat.nama,
            category_urutan: cat.urutan,
            venue_nama: v ? v.nama : null,
            venue_kota: v ? v.kota : null,
            tertarik: conversations.filter((c) => c.listing_id === nearestListing.id).length,
            is_favorite: false,
          });
        }

        return { rows: results };
      }

      throw new Error(`Unhandled query: ${q}`);
    },
  };
}

describe('GET /events/trending (BR-6)', () => {
  function insertEvent(db, overrides = {}) {
    const id = db.events.length + 1;
    const ev = {
      id,
      category_id: 1,
      nama: `Event ${id}`,
      poster_url: `/uploads/event${id}.jpg`,
      hidden: false,
      ...overrides,
    };
    db.events.push(ev);
    return ev;
  }

  function insertListing(db, overrides = {}) {
    const id = db.listings.length + 1;
    const now = Date.now();
    const listing = {
      id,
      event_id: 1,
      seller_id: 1,
      venue_id: 1,
      venue_teks: null,
      kota: 'Surabaya',
      waktu_acara: new Date(now + 48 * 3600_000).toISOString(),
      jenis: 'limited',
      tipe: 'digital',
      seksi: 'CAT 1',
      harga: 500000,
      harga_asli: null,
      jumlah_total: 2,
      jumlah_terjual: 0,
      satuan: true,
      terikat_nama: 'tidak',
      serah_terima: ['transfer_eticket'],
      ref_lat: -7.262,
      ref_lng: 112.751,
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

  it('menolak koordinat yang tidak berpasangan dengan status 422', async () => {
    const db = createTrendingMockDb();
    const app = createApp({ db, useRateLimit: false });

    const res1 = await request(app).get('/api/v1/events/trending?lat=-7.26');
    expect(res1.status).toBe(422);
    expect(res1.body.error.code).toBe('VALIDATION_ERROR');

    const res2 = await request(app).get('/api/v1/events/trending?lng=112.75');
    expect(res2.status).toBe(422);
    expect(res2.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('menghitung skor_event = active_listings + 0.5 * convs_7d untuk kategori acara', async () => {
    const db = createTrendingMockDb();
    const app = createApp({ db, useRateLimit: false });
    const now = Date.now();

    // Event 1 (Konser): 2 listing aktif, 0 percakapan -> skor = 2 + 0 = 2.0
    const ev1 = insertEvent(db, { id: 1, category_id: 1, nama: 'Konser A' });
    insertListing(db, { id: 1, event_id: ev1.id });
    insertListing(db, { id: 2, event_id: ev1.id });

    // Event 2 (Konser): 1 listing aktif, 4 percakapan dalam 7 hari -> skor = 1 + 0.5 * 4 = 3.0
    const ev2 = insertEvent(db, { id: 2, category_id: 1, nama: 'Konser B' });
    const l3 = insertListing(db, { id: 3, event_id: ev2.id });
    for (let i = 1; i <= 4; i++) {
      db.conversations.push({
        id: i,
        listing_id: l3.id,
        created_at: new Date(now - i * 86400_000).toISOString(), // 1..4 hari lalu
      });
    }

    // Percakapan usang (> 7 hari lalu) tidak boleh dihitung
    db.conversations.push({
      id: 5,
      listing_id: l3.id,
      created_at: new Date(now - 10 * 86400_000).toISOString(),
    });

    const res = await request(app).get('/api/v1/events/trending');
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
    expect(res.body.data[0]).toEqual({
      type: 'event',
      category_slug: 'konser-festival',
      event: {
        id: ev2.id,
        nama: 'Konser B',
        poster_url: ev2.poster_url,
      },
    });
  });

  it('melewati banner nearest jika pengguna tidak memberikan lat/lng', async () => {
    const db = createTrendingMockDb();
    const app = createApp({ db, useRateLimit: false });

    // Konser (event)
    const ev1 = insertEvent(db, { id: 1, category_id: 1, nama: 'Konser Jazz' });
    insertListing(db, { id: 1, event_id: ev1.id });

    // Bioskop (nearest)
    const ev2 = insertEvent(db, { id: 2, category_id: 2, nama: 'Film Action' });
    insertListing(db, { id: 2, event_id: ev2.id });

    // Tanpa koordinat -> hanya banner event (Konser Jazz)
    const anonRes = await request(app).get('/api/v1/events/trending');
    expect(anonRes.status).toBe(200);
    expect(anonRes.body.data.length).toBe(1);
    expect(anonRes.body.data[0].type).toBe('event');
    expect(anonRes.body.data[0].category_slug).toBe('konser-festival');
  });

  it('menampilkan banner nearest untuk bioskop/wisata saat ada koordinat pengguna', async () => {
    const db = createTrendingMockDb();
    const app = createApp({ db, useRateLimit: false });

    // Bioskop (category_id: 2)
    const evBioskop = insertEvent(db, { id: 20, category_id: 2, nama: 'Bioskop Hits' });
    // Listing 1: Grand City Surabaya (-7.262, 112.751) -> dekat user di (-7.263, 112.745)
    insertListing(db, {
      id: 201,
      event_id: evBioskop.id,
      ref_lat: -7.262,
      ref_lng: 112.751,
    });
    // Listing 2: GBK Jakarta -> jauh
    insertListing(db, {
      id: 202,
      event_id: evBioskop.id,
      ref_lat: -6.218,
      ref_lng: 106.802,
    });

    const res = await request(app).get(
      '/api/v1/events/trending?lat=-7.263&lng=112.745'
    );
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
    const banner = res.body.data[0];
    expect(banner.type).toBe('nearest');
    expect(banner.category_slug).toBe('bioskop');
    expect(banner.listing.id).toBe(201);
    expect(banner.listing.jarak_km).toBeLessThan(5);
  });

  it('mengurutkan banner sesuai categories.urutan dan melewati kategori tanpa data aktif', async () => {
    const db = createTrendingMockDb();
    const app = createApp({ db, useRateLimit: false });

    // Category 1: konser-festival (urutan: 1)
    const ev1 = insertEvent(db, { id: 10, category_id: 1, nama: 'Festival Musik' });
    insertListing(db, { id: 100, event_id: ev1.id });

    // Category 2: bioskop (urutan: 2) -> tidak ada listing -> dilewati!

    // Category 3: olahraga (urutan: 3)
    const ev3 = insertEvent(db, { id: 30, category_id: 3, nama: 'Laga Akbar' });
    insertListing(db, { id: 300, event_id: ev3.id });

    // Category 4: wisata (urutan: 4)
    const ev4 = insertEvent(db, { id: 40, category_id: 4, nama: 'Wisata Safari' });
    insertListing(db, {
      id: 400,
      event_id: ev4.id,
      ref_lat: -7.262,
      ref_lng: 112.751,
    });

    const res = await request(app).get(
      '/api/v1/events/trending?lat=-7.263&lng=112.745'
    );
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(3);
    // Urutan: konser-festival (1) -> olahraga (3) -> wisata (4)
    expect(res.body.data.map((b) => b.category_slug)).toEqual([
      'konser-festival',
      'olahraga',
      'wisata',
    ]);
  });
});
