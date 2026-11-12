# HANDOFF.md — Droptix

## Selesai

- **M0 (T0.1–T0.4)** — Backend health, tema token, komponen bersama, Component Gallery.
- **T1.1 & T1.2** — Migrasi `001_init.sql`, pool koneksi, `migrate`, dan `seed` idempoten + aset PNG lokal.
- **T1.3** — Backend auth & `/me`: format error seragam (`utils/errors.js`), validasi `zod`, JWT (`middleware/auth.js`), rate limit (`middleware/rateLimit.js`), `POST /auth/register`, `POST /auth/login`, `GET/PUT /me`, `PUT /me/password`. 4 suite / 18 tes Jest lulus (mock DB).

## Sedang

Menunggu perintah "lanjut".

## Langkah berikutnya

- **T1.4** — Flutter: klien API (`dio`, interceptor token), layar login dan register (kotak persetujuan syarat), sesi tersimpan, edit profil, ganti password, logout, alur "login saat aksi" untuk tamu.
