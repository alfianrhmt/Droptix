'use strict';

const bcrypt = require('bcryptjs');
const { pool, withTransaction } = require('../src/db/pool');
const { CATEGORIES, VENUES, USERS, EVENTS, LISTINGS } = require('./seed_data');

const DEV_PASSWORD = 'Droptix123!';

function normalizeEventName(nama) {
  return nama.trim().toLowerCase().replace(/\s+/g, ' ');
}

function futureDateFromNow(offsetHours) {
  return new Date(Date.now() + offsetHours * 60 * 60 * 1000);
}

/**
 * Menjalankan seed idempoten untuk seluruh data contoh Droptix.
 * Aman dijalankan berulang kali tanpa membuat duplikasi.
 */
async function runSeed({
  targetPool = pool,
  logger = console,
} = {}) {
  const passwordHash = await bcrypt.hash(DEV_PASSWORD, 10);

  return withTransaction(async (client) => {
    // 1. Categories (upsert by slug)
    const categoryIds = new Map();
    for (const cat of CATEGORIES) {
      const { rows } = await client.query(
        `INSERT INTO categories (slug, nama, ikon, urutan)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (slug) DO UPDATE
           SET nama = EXCLUDED.nama,
               ikon = EXCLUDED.ikon,
               urutan = EXCLUDED.urutan
         RETURNING id`,
        [cat.slug, cat.nama, cat.ikon, cat.urutan]
      );
      categoryIds.set(cat.slug, rows[0].id);
    }

    // 2. Venues (idempoten berdasarkan nama + kota)
    const venueMap = new Map();
    for (const v of VENUES) {
      const existing = await client.query(
        'SELECT id, lat, lng FROM venues WHERE nama = $1 AND kota = $2 LIMIT 1',
        [v.nama, v.kota]
      );
      if (existing.rows.length > 0) {
        venueMap.set(v.nama, existing.rows[0]);
      } else {
        const { rows } = await client.query(
          `INSERT INTO venues (nama, kota, alamat, lat, lng)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id, lat, lng`,
          [v.nama, v.kota, v.alamat, v.lat, v.lng]
        );
        venueMap.set(v.nama, rows[0]);
      }
    }

    // 3. Users (upsert by email)
    const userIds = new Map();
    for (const u of USERS) {
      const existing = await client.query(
        'SELECT id FROM users WHERE email = $1 LIMIT 1',
        [u.email]
      );
      if (existing.rows.length > 0) {
        userIds.set(u.email, existing.rows[0].id);
      } else {
        const { rows } = await client.query(
          `INSERT INTO users (nama, email, password_hash, no_wa, kota)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id`,
          [u.nama, u.email, passwordHash, u.no_wa, u.kota]
        );
        userIds.set(u.email, rows[0].id);
      }
    }

    // 4. Events (idempoten berdasarkan nama_normal + category_id)
    const eventIds = new Map();
    for (const ev of EVENTS) {
      const categoryId = categoryIds.get(ev.categorySlug);
      const venue = venueMap.get(ev.venueNama);
      const createdBy = userIds.get(ev.createdByEmail);
      const namaNormal = normalizeEventName(ev.nama);

      const existing = await client.query(
        'SELECT id FROM events WHERE nama_normal = $1 AND category_id = $2 LIMIT 1',
        [namaNormal, categoryId]
      );
      if (existing.rows.length > 0) {
        eventIds.set(ev.nama, existing.rows[0].id);
      } else {
        const { rows } = await client.query(
          `INSERT INTO events (category_id, nama, nama_normal, poster_url, venue_id, tanggal, created_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id`,
          [
            categoryId,
            ev.nama,
            namaNormal,
            ev.poster_url,
            venue ? venue.id : null,
            futureDateFromNow(ev.offsetHours),
            createdBy,
          ]
        );
        eventIds.set(ev.nama, rows[0].id);
      }
    }

    // 5. Listings (idempoten berdasarkan event_id + seller_id + seksi + jenis + tipe)
    const listingIds = [];
    for (const lst of LISTINGS) {
      const eventId = eventIds.get(lst.eventNama);
      const sellerId = userIds.get(lst.sellerEmail);
      const venue = venueMap.get(lst.venueNama);
      const venueData = VENUES.find((v) => v.nama === lst.venueNama);

      const existing = await client.query(
        `SELECT id FROM listings
         WHERE event_id = $1 AND seller_id = $2
           AND COALESCE(seksi, '') = $3 AND jenis = $4 AND tipe = $5
         LIMIT 1`,
        [eventId, sellerId, lst.seksi || '', lst.jenis, lst.tipe]
      );

      if (existing.rows.length > 0) {
        listingIds.push(existing.rows[0].id);
        continue;
      }

      const refLat =
        lst.tipe === 'fisik'
          ? (lst.lokasi_penjual_lat ?? null)
          : (venue?.lat ?? null);
      const refLng =
        lst.tipe === 'fisik'
          ? (lst.lokasi_penjual_lng ?? null)
          : (venue?.lng ?? null);

      const { rows } = await client.query(
        `INSERT INTO listings (
           event_id, seller_id, venue_id, kota, waktu_acara,
           jenis, tipe, seksi, no_kursi,
           harga, harga_asli, jumlah_total, jumlah_terjual, satuan,
           terikat_nama, serah_terima,
           lokasi_penjual_kota, lokasi_penjual_lat, lokasi_penjual_lng,
           ref_lat, ref_lng, catatan, izinkan_wa
         )
         VALUES (
           $1, $2, $3, $4, $5,
           $6, $7, $8, $9,
           $10, $11, $12, $13, $14,
           $15, $16,
           $17, $18, $19,
           $20, $21, $22, $23
         )
         RETURNING id`,
        [
          eventId,
          sellerId,
          venue ? venue.id : null,
          venueData ? venueData.kota : 'Surabaya',
          futureDateFromNow(lst.offsetHours),
          lst.jenis,
          lst.tipe,
          lst.seksi,
          lst.no_kursi,
          lst.harga,
          lst.harga_asli,
          lst.jumlah_total,
          lst.jumlah_terjual,
          lst.satuan,
          lst.terikat_nama,
          lst.serah_terima,
          lst.lokasi_penjual_kota || null,
          lst.lokasi_penjual_lat ?? null,
          lst.lokasi_penjual_lng ?? null,
          refLat,
          refLng,
          lst.catatan,
          lst.izinkan_wa,
        ]
      );

      const newListingId = rows[0].id;
      listingIds.push(newListingId);

      for (let i = 0; i < (lst.photos || []).length; i++) {
        await client.query(
          'INSERT INTO listing_photos (listing_id, url, urutan) VALUES ($1, $2, $3)',
          [newListingId, lst.photos[i], i]
        );
      }
    }

    // 6. Conversations, messages & favorites
    const rakaId = userIds.get('raka@droptix.dev');
    const dinaId = userIds.get('dina@droptix.dev');
    const bagasId = userIds.get('bagas@droptix.dev');

    const convSpecs = [
      {
        listingId: listingIds[0], // seller: raka
        buyerId: dinaId,
        sellerId: rakaId,
        buyerReadOffsetMin: 20, // unread untuk buyer
        sellerReadOffsetMin: 0,
        messages: [
          { senderId: dinaId, isi: 'Halo kak, tiket Festival A masih ada?', offsetMin: 25 },
          { senderId: rakaId, isi: 'Masih ada 2 tiket kak, siap transfer.', offsetMin: 5 },
        ],
      },
      {
        listingId: listingIds[0], // seller: raka
        buyerId: bagasId,
        sellerId: rakaId,
        buyerReadOffsetMin: 0,
        sellerReadOffsetMin: 60, // unread untuk seller
        messages: [
          { senderId: bagasId, isi: 'Boleh ambil 1 tiket aja?', offsetMin: 10 },
        ],
      },
      {
        listingId: listingIds[1], // seller: dina
        buyerId: rakaId,
        sellerId: dinaId,
        buyerReadOffsetMin: null, // belum pernah dibaca buyer
        sellerReadOffsetMin: 0,
        messages: [
          { senderId: rakaId, isi: 'Bisa COD di lobi Grand City?', offsetMin: 30 },
          { senderId: dinaId, isi: 'Bisa kak, jam 17.30 ya.', offsetMin: 12 },
        ],
      },
    ];

    for (const c of convSpecs) {
      const existing = await client.query(
        'SELECT id FROM conversations WHERE listing_id = $1 AND buyer_id = $2 LIMIT 1',
        [c.listingId, c.buyerId]
      );
      if (existing.rows.length > 0) continue;

      const lastMsg = c.messages[c.messages.length - 1];
      const lastAt = new Date(Date.now() - lastMsg.offsetMin * 60 * 1000);
      const buyerReadAt =
        c.buyerReadOffsetMin === null
          ? null
          : new Date(Date.now() - c.buyerReadOffsetMin * 60 * 1000);
      const sellerReadAt =
        c.sellerReadOffsetMin === null
          ? null
          : new Date(Date.now() - c.sellerReadOffsetMin * 60 * 1000);

      const { rows } = await client.query(
        `INSERT INTO conversations (
           listing_id, buyer_id, seller_id,
           last_message_at, last_message_preview,
           buyer_last_read_at, seller_last_read_at
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id`,
        [
          c.listingId,
          c.buyerId,
          c.sellerId,
          lastAt,
          lastMsg.isi.slice(0, 80),
          buyerReadAt,
          sellerReadAt,
        ]
      );
      const convId = rows[0].id;

      for (const m of c.messages) {
        const createdAt = new Date(Date.now() - m.offsetMin * 60 * 1000);
        await client.query(
          'INSERT INTO messages (conversation_id, sender_id, isi, created_at) VALUES ($1, $2, $3, $4)',
          [convId, m.senderId, m.isi, createdAt]
        );
      }
    }

    // Favorites
    const favPairs = [
      [dinaId, listingIds[0]],
      [dinaId, listingIds[4]],
      [bagasId, listingIds[0]],
      [rakaId, listingIds[1]],
      [rakaId, listingIds[6]],
    ];
    for (const [uid, lid] of favPairs) {
      await client.query(
        `INSERT INTO favorites (user_id, listing_id)
         VALUES ($1, $2)
         ON CONFLICT (user_id, listing_id) DO NOTHING`,
        [uid, lid]
      );
    }

    logger.log(
      `[seed] Selesai: ${CATEGORIES.length} kategori, ${VENUES.length} venue, ${USERS.length} pengguna, ${EVENTS.length} event, ${LISTINGS.length} listing.`
    );

    return {
      categories: CATEGORIES.length,
      venues: VENUES.length,
      users: USERS.length,
      events: EVENTS.length,
      listings: LISTINGS.length,
    };
  }, targetPool);
}

if (require.main === module) {
  runSeed()
    .then(async () => {
      await pool.end();
      process.exit(0);
    })
    .catch(async (err) => {
      console.error('[seed] Gagal:', err.message);
      await pool.end();
      process.exit(1);
    });
}

module.exports = { runSeed, DEV_PASSWORD, normalizeEventName };
