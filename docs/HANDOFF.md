# HANDOFF — Droptix

## Selesai
- **T1.5**: Tes Jest untuk auth ([auth.test.js](file:///c:/Users/bstar/Desktop/Droptix/backend/tests/auth.test.js)) — registrasi, email ganda, validasi syarat/password, login salah (email/password), akun dibekukan (login & `/me`), token kedaluwarsa/tidak valid, ganti password, dan rate limit (`4 suites, 18 tests passed`). Milestone M1 selesai.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai M2 (**T2.1**).

## Langkah berikutnya
- **T2.1**: Backend `GET /categories`, `GET /venues`, `GET /events`, `POST /events` (cek nama mirip, `force`, batas 5 per hari), `PUT /events/:id` (kunci), `POST /uploads` (validasi isi berkas).
