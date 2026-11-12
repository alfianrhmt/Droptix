# HANDOFF — Droptix

## Selesai
- **T3.1**: Backend CRUD & manajemen listing ([listings.js](file:///c:/Users/bstar/Desktop/Droptix/backend/src/routes/listings.js), [auth.js](file:///c:/Users/bstar/Desktop/Droptix/backend/src/middleware/auth.js) `createOptionalAuth`): `POST /listings` (validasi profil `kota` & `no_wa` untuk `izinkan_wa`, `serah_terima`, foto `/uploads/`, duplikat 10 menit, pengisian `ref_lat`/`ref_lng`), `PUT`, `PATCH /stock`, `POST /confirm`, `DELETE` (soft), `GET /listings/:id` (`6 suites, 29 tests passed`).

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T3.2.

## Langkah berikutnya
- **T3.2**: Flutter alur Sell 5 langkah, indikator kemajuan, sakelar WhatsApp, pratinjau, posting.
