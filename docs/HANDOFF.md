# HANDOFF.md — Droptix

## Selesai

- **M0 (T0.1–T0.4)** — Fondasi backend/Docker, tema token, komponen bersama, Component Gallery.
- **T1.1** — Migrasi `001_init.sql`, pool koneksi, skrip `migrate` idempoten.
- **T1.2** — Seed idempoten di `backend/db/seed.js` & `seed_data.js` (`npm run seed`), 5 kategori, 28 venue (koordinat diverifikasi; 2 area perkiraan disetel `NULL`), 3 akun dev (password di `README.md`), 10 event, 16 listing, percakapan + pesan + favorit, serta 9 gambar lokal di `backend/uploads/seed/`. 10 unit test lulus (mock DB; belum diuji ke Postgres live).

## Sedang

Menunggu perintah "lanjut".

## Langkah berikutnya

- **T1.3** — Backend: format error seragam, middleware validasi (`zod`), auth JWT, rate limit, endpoint auth & `/me`.
