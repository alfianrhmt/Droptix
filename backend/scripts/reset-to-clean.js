'use strict';

const { pool, withTransaction } = require('../src/db/pool');
const { CATEGORIES, VENUES } = require('../db/seed_data');

async function resetToClean() {
  console.log('--- Droptix Database Reset: Membersihkan Data Dummy & Mengisi Venue Lengkap ---');

  await withTransaction(async (client) => {
    // 1. Kosongkan tabel dinamis user & transaksi
    console.log('1. Mengosongkan data transaksi, pesan, listing, event, dan user...');
    await client.query(`
      TRUNCATE TABLE 
        messages, 
        conversations, 
        favorites, 
        listing_photos, 
        listings, 
        events, 
        users, 
        reports, 
        blocks 
      RESTART IDENTITY CASCADE;
    `);

    // 2. Pastikan Kategori (Categories) lengkap dan terbarui
    console.log('2. Memastikan master kategori lengkap...');
    for (const cat of CATEGORIES) {
      await client.query(
        `INSERT INTO categories (slug, nama, ikon, urutan)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (slug) DO UPDATE
           SET nama = EXCLUDED.nama,
               ikon = EXCLUDED.ikon,
               urutan = EXCLUDED.urutan`,
        [cat.slug, cat.nama, cat.ikon, cat.urutan]
      );
    }

    // 3. Reset dan isi seluruh master venue lengkap
    console.log(`3. Memperbarui ${VENUES.length} venue populer di seluruh Indonesia...`);
    await client.query('TRUNCATE TABLE venues RESTART IDENTITY CASCADE;');

    for (const v of VENUES) {
      await client.query(
        `INSERT INTO venues (nama, kota, alamat, lat, lng)
         VALUES ($1, $2, $3, $4, $5)`,
        [v.nama, v.kota, v.alamat, v.lat, v.lng]
      );
    }
  });

  const { rows: catCount } = await pool.query('SELECT COUNT(*)::int AS count FROM categories');
  const { rows: venCount } = await pool.query('SELECT COUNT(*)::int AS count FROM venues');
  const { rows: listCount } = await pool.query('SELECT COUNT(*)::int AS count FROM listings');
  const { rows: userCount } = await pool.query('SELECT COUNT(*)::int AS count FROM users');

  console.log('----------------------------------------------------');
  console.log('Status Database:');
  console.log(`- Kategori : ${catCount[0].count} kategori aktif`);
  console.log(`- Venue    : ${venCount[0].count} venue siap digunakan`);
  console.log(`- User     : ${userCount[0].count} (siap registrasi baru)`);
  console.log(`- Listing  : ${listCount[0].count} (siap diisi tiket baru)`);
  console.log('----------------------------------------------------');
  console.log('Reset berhasil!');
}

resetToClean()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error saat reset database:', err);
    process.exit(1);
  });
