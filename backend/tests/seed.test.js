'use strict';

const fs = require('fs');
const path = require('path');
const { runSeed } = require('../db/seed');
const {
  CATEGORIES,
  VENUES,
  USERS,
  EVENTS,
  LISTINGS,
} = require('../db/seed_data');

describe('Seed data & idempotensi T1.2', () => {
  it('memenuhi jumlah dan variasi data sesuai DATABASE.md bagian 4', () => {
    expect(CATEGORIES.map((c) => c.slug)).toEqual([
      'konser-festival',
      'bioskop',
      'olahraga',
      'wisata',
      'hiburan-lain',
    ]);
    expect(VENUES.length).toBeGreaterThanOrEqual(25);
    expect(VENUES.length).toBeLessThanOrEqual(30);
    expect(USERS.length).toBe(3);

    expect(EVENTS.length).toBeGreaterThanOrEqual(8);
    expect(EVENTS.length).toBeLessThanOrEqual(10);
    const eventCats = new Set(EVENTS.map((e) => e.categorySlug));
    expect(eventCats.size).toBe(5);
    expect(EVENTS.some((e) => e.poster_url === null)).toBe(true);

    expect(LISTINGS.length).toBeGreaterThanOrEqual(15);
    expect(LISTINGS.length).toBeLessThanOrEqual(20);
    expect(LISTINGS.some((l) => l.jenis === 'limited')).toBe(true);
    expect(LISTINGS.some((l) => l.jenis === 'last_minute')).toBe(true);
    expect(LISTINGS.some((l) => l.tipe === 'digital')).toBe(true);
    expect(LISTINGS.some((l) => l.tipe === 'fisik')).toBe(true);
    expect(LISTINGS.some((l) => l.jumlah_terjual > 0)).toBe(true);
    expect(LISTINGS.some((l) => l.harga < l.harga_asli)).toBe(true);
    expect(LISTINGS.some((l) => l.harga > l.harga_asli)).toBe(true);
    expect(LISTINGS.some((l) => l.jumlah_total > 1)).toBe(true);
    expect(LISTINGS.some((l) => l.offsetHours <= 3)).toBe(true);
  });

  it('berkas gambar lokal seed tersedia di backend/uploads/seed/', () => {
    const seedDir = path.join(__dirname, '../uploads/seed');
    for (const ev of EVENTS) {
      if (ev.poster_url) {
        const filename = path.basename(ev.poster_url);
        expect(fs.existsSync(path.join(seedDir, filename))).toBe(true);
      }
    }
    for (const lst of LISTINGS) {
      for (const photo of lst.photos || []) {
        const filename = path.basename(photo);
        expect(fs.existsSync(path.join(seedDir, filename))).toBe(true);
      }
    }
  });

  it('runSeed bersifat idempoten saat dijalankan dua kali', async () => {
    const store = {
      categories: new Map(),
      venues: [],
      users: new Map(),
      events: [],
      listings: [],
      photos: [],
      conversations: [],
      messages: [],
      favorites: new Set(),
    };

    const fakeClient = {
      query: async (sql, params = []) => {
        const q = sql.trim();
        if (q === 'BEGIN' || q === 'COMMIT' || q === 'ROLLBACK') {
          return { rows: [] };
        }
        if (q.startsWith('INSERT INTO categories')) {
          const [slug, nama, ikon, urutan] = params;
          if (!store.categories.has(slug)) {
            store.categories.set(slug, {
              id: store.categories.size + 1,
              slug,
              nama,
              ikon,
              urutan,
            });
          }
          return { rows: [{ id: store.categories.get(slug).id }] };
        }
        if (q.startsWith('SELECT id, lat, lng FROM venues')) {
          const found = store.venues.find(
            (v) => v.nama === params[0] && v.kota === params[1]
          );
          return { rows: found ? [found] : [] };
        }
        if (q.startsWith('INSERT INTO venues')) {
          const v = {
            id: store.venues.length + 1,
            nama: params[0],
            kota: params[1],
            lat: params[3],
            lng: params[4],
          };
          store.venues.push(v);
          return { rows: [v] };
        }
        if (q.startsWith('SELECT id FROM users WHERE email')) {
          const u = store.users.get(params[0]);
          return { rows: u ? [{ id: u.id }] : [] };
        }
        if (q.startsWith('INSERT INTO users')) {
          const u = { id: store.users.size + 1, email: params[1] };
          store.users.set(params[1], u);
          return { rows: [{ id: u.id }] };
        }
        if (q.startsWith('SELECT id FROM events')) {
          const found = store.events.find(
            (e) => e.nama_normal === params[0] && e.category_id === params[1]
          );
          return { rows: found ? [{ id: found.id }] : [] };
        }
        if (q.startsWith('INSERT INTO events')) {
          const ev = {
            id: store.events.length + 1,
            category_id: params[0],
            nama_normal: params[2],
          };
          store.events.push(ev);
          return { rows: [{ id: ev.id }] };
        }
        if (q.startsWith('SELECT id FROM listings')) {
          const found = store.listings.find(
            (l) =>
              l.event_id === params[0] &&
              l.seller_id === params[1] &&
              (l.seksi || '') === params[2] &&
              l.jenis === params[3] &&
              l.tipe === params[4]
          );
          return { rows: found ? [{ id: found.id }] : [] };
        }
        if (q.startsWith('INSERT INTO listings')) {
          const l = {
            id: store.listings.length + 1,
            event_id: params[0],
            seller_id: params[1],
            seksi: params[7],
            jenis: params[5],
            tipe: params[6],
          };
          store.listings.push(l);
          return { rows: [{ id: l.id }] };
        }
        if (q.startsWith('INSERT INTO listing_photos')) {
          store.photos.push(params);
          return { rows: [] };
        }
        if (q.startsWith('SELECT id FROM conversations')) {
          const found = store.conversations.find(
            (c) => c.listing_id === params[0] && c.buyer_id === params[1]
          );
          return { rows: found ? [{ id: found.id }] : [] };
        }
        if (q.startsWith('INSERT INTO conversations')) {
          const c = {
            id: store.conversations.length + 1,
            listing_id: params[0],
            buyer_id: params[1],
          };
          store.conversations.push(c);
          return { rows: [{ id: c.id }] };
        }
        if (q.startsWith('INSERT INTO messages')) {
          store.messages.push(params);
          return { rows: [] };
        }
        if (q.startsWith('INSERT INTO favorites')) {
          store.favorites.add(`${params[0]}:${params[1]}`);
          return { rows: [] };
        }
        throw new Error(`Unhandled query in test: ${q}`);
      },
      release: () => {},
    };

    const fakePool = { connect: async () => fakeClient };
    const silentLogger = { log: () => {} };

    await runSeed({ targetPool: fakePool, logger: silentLogger });
    const afterFirst = {
      categories: store.categories.size,
      venues: store.venues.length,
      users: store.users.size,
      events: store.events.length,
      listings: store.listings.length,
      conversations: store.conversations.length,
      messages: store.messages.length,
      favorites: store.favorites.size,
    };

    await runSeed({ targetPool: fakePool, logger: silentLogger });
    expect({
      categories: store.categories.size,
      venues: store.venues.length,
      users: store.users.size,
      events: store.events.length,
      listings: store.listings.length,
      conversations: store.conversations.length,
      messages: store.messages.length,
      favorites: store.favorites.size,
    }).toEqual(afterFirst);
  });
});

