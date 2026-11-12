# HANDOFF — Droptix

## Selesai
- **T2.1**: Backend `GET /categories`, `GET /venues`, `GET /events`, `POST /events` (validasi kategori wajib venue/tanggal, cek nama mirip `409 SIMILAR_EVENT_EXISTS`, `force`, batas 5/hari), `PUT /events/:id` (`403 EVENT_LOCKED`), dan `POST /uploads` + sajian statis `/uploads` dengan validasi magic bytes (`5 suites, 22 tests passed`).

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T2.2.

## Langkah berikutnya
- **T2.2**: Flutter alur izin lokasi dengan fallback pilih kota manual, pil lokasi di header yang bisa diganti.
