# TASKS.md — Droptix

Urutan pengerjaan untuk agen. Kerjakan **satu tugas per sesi**, sesuai `AGENTS.md`. Pendekatan: **irisan vertikal** (backend dan layar Flutter untuk satu fitur dikerjakan berurutan), supaya hasilnya selalu bisa dilihat dan diuji.

Perkiraan jadwal (7 minggu):

| Minggu | Milestone |
|---|---|
| 1 | M0, M1 |
| 2 | M2, M3 |
| 3 | M3 (sisa), M4 |
| 4 | M4 (sisa), M5 |
| 5 | M6 (chat) |
| 6 | M7 (laporan, blokir, hukum), M8 (penyempurnaan) |
| 7 | M8 (deploy, uji akhir, finalisasi) |

**Titik pembekuan scope: akhir minggu 5** (setelah chat berjalan). Setelah itu hanya perbaikan, penyempurnaan, deploy, dan uji. Draf artikel dan video dikerjakan paralel sejak minggu 4. Jika jadwal molor, potong fitur bonus lebih dulu, bukan uji dan deploy.

Centang `[x]` setelah tugas lolos kriteria "selesai" di `AGENTS.md` bagian 8.

---

## M0 — Fondasi dan kalibrasi desain

- [x] **T0.1** Struktur repo sesuai `AGENTS.md`, `docker-compose.yml` (API + PostgreSQL), backend Express dengan `GET /api/v1/health`, `.env.example`, README awal.
- [x] **T0.2** Proyek Flutter: token (warna, tipografi, jarak, radius) di `core/theme`, tema gelap Poppins, `AppBackground` dengan glow teal.
- [x] **T0.3** Komponen bersama (`DESIGN.md` bagian 4 dan 9b): `AppHeader`, `SearchBar`, `BannerCarousel`, `ResellTypeTiles`, `QuickDateGrid`, `CategoryRow`, `SectionHeader`, `PosterCard`, `ListingRow`, `FilterChipRow`, badge, `BottomNav`, `PrimaryButton`, `StatsCard`, `UnreadBadge`, `ConversationRow`, `ChatListingCard`, `ChatBubble`, `ChatInput`, keadaan loading/kosong/error.
- [x] **T0.4** Layar **Component Gallery** berisi semua komponen dengan data contoh. **BERHENTI. Tunggu persetujuan pengguna sebelum lanjut.**

**Selesai jika:** gallery tampil sesuai `DESIGN.md` di 390×844 dan 360×740, hanya memakai token, tanpa blur, tanpa warna kuning.

## M1 — Database dan akun

- [x] **T1.1** Migrasi `001_init.sql` dari `DATABASE.md`, skrip `migrate`, pool koneksi.
- [x] **T1.2** Seed idempoten (kategori, venue, pengguna, event, listing, percakapan dan pesan, favorit). Koordinat venue diverifikasi, bukan dikarang.
- [x] **T1.3** Backend: format error seragam, middleware validasi (zod), auth JWT, rate limit; `POST /auth/register` (dengan `setuju_syarat`), `POST /auth/login` (tolak akun `banned_at`), `GET/PUT /me`, `PUT /me/password`.
- [x] **T1.4** Flutter: klien API (dio, interceptor token), layar login dan register (kotak persetujuan syarat), sesi tersimpan, edit profil, ganti password, logout, alur "login saat aksi" untuk tamu.
- [x] **T1.5** Tes Jest untuk auth (registrasi, email ganda, login salah, akun dibekukan, token kedaluwarsa).

**Selesai jika:** skenario uji 2 di `PRD.md` bagian 8 berjalan (kecuali bagian lokasi).

## M2 — Lokasi, event, venue, unggahan

- [x] **T2.1** Backend: `GET /categories`, `GET /venues`, `GET /events`, `POST /events` (cek nama mirip, `force`, batas 5 per hari), `PUT /events/:id` (kunci), `POST /uploads` (validasi isi berkas).
- [ ] **T2.2** Flutter: alur izin lokasi dengan fallback pilih kota manual, pil lokasi di header yang bisa diganti.
- [ ] **T2.3** Flutter: pemilih event (pencarian, "Tambah baru", dialog "Maksudmu ini?", unggah dan crop poster 2:3, poster cadangan).
- [ ] **T2.4** Tes: pembuatan event (nama mirip, batas harian, kunci).

**Selesai jika:** skenario uji 3 berjalan.

## M3 — Membuat dan mengelola listing

- [ ] **T3.1** Backend: `POST /listings` dengan semua validasi `API.md` (termasuk `izinkan_wa`), `PUT`, `DELETE` (soft), `PATCH /stock`, `POST /confirm`, `GET /listings/:id`, pengisian `ref_lat`/`ref_lng`, status turunan (termasuk `hidden`).
- [ ] **T3.2** Flutter: alur Sell 5 langkah, indikator kemajuan, sakelar WhatsApp, pratinjau, posting.
- [ ] **T3.3** Flutter: halaman Activity segmen **Selling** (ubah terjual, tandai terjual semua, konfirmasi, edit, hapus).
- [ ] **T3.4** Tes: validasi listing, aturan stok, status turunan, kepemilikan.

**Selesai jika:** skenario uji 4 dan 7 berjalan.

## M4 — Menemukan tiket (pencarian dan Home)

- [ ] **T4.1** Backend: `GET /listings` dengan semua filter, urutan, pagination, dan jarak Haversine; kedaluwarsa, `hidden`, dan penjual dibekukan dicek saat query.
- [ ] **T4.2** Backend: skor relevansi (BR-5) dengan bobot di satu berkas konfigurasi, `sort=relevan`, normalisasi ulang tanpa lokasi.
- [ ] **T4.3** Backend: `GET /events/trending` (BR-6, memakai jumlah percakapan baru 7 hari).
- [ ] **T4.4** Flutter: halaman pencarian dan kategori (chip filter, urutan, daftar `ListingRow`, 5 pencarian terakhir, keadaan kosong).
- [ ] **T4.5** Flutter: Home dengan semua section (`DESIGN.md` bagian 5), scroll tanpa batas pada "Baru Ditambahkan".
- [ ] **T4.6** Tes: filter, urutan, kedaluwarsa, skor relevansi (dua listing dengan jarak berbeda, bobot berbeda per jenis).

**Selesai jika:** skenario uji 5 dan 8 berjalan, dan urutan "Relevan" berubah wajar saat lokasi diganti.

## M5 — Detail listing dan favorit

- [ ] **T5.1** Backend: `POST/DELETE /listings/:id/favorite`, `GET /me/favorites`.
- [ ] **T5.2** Flutter: halaman detail (`DESIGN.md` bagian 7), label status, favorit, bagikan, tombol "Chat dengan penjual" (sementara membuka layar placeholder sampai M6 selesai).
- [ ] **T5.3** Flutter: Activity segmen **Saved**.

**Selesai jika:** detail menampilkan semua informasi di `PRD.md` FR-5 tanpa email atau nomor WhatsApp.

## M6 — Chat dalam aplikasi

- [ ] **T6.1** Backend: `GET /listings/:id/conversation`, `POST /listings/:id/conversations` (atomik dengan pesan pertama), `GET /conversations`, `GET /conversations/:id`, `GET /conversations/:id/messages` (paginasi `before`), `POST /conversations/:id/messages`, `POST /conversations/:id/read`, `GET /me/unread`, aturan BR-12 dan batas laju.
- [ ] **T6.2** Backend: Socket.IO (`realtime/`) dengan autentikasi JWT, room per pengguna, event `message:new` dan `unread:update`.
- [ ] **T6.3** Flutter: koneksi socket tunggal (login/logout, sambung ulang otomatis), layar chat (kartu listing, bubble, input, saran pesan cepat, polling cadangan), Activity segmen **Chats** (`ConversationRow`), badge belum dibaca di ikon Activity.
- [ ] **T6.4** Backend dan Flutter: opsi WhatsApp (`POST /conversations/:id/whatsapp`, item menu "Lanjut via WhatsApp" di chat, hanya jika `izinkan_wa`).
- [ ] **T6.5** Tes: satu percakapan per (listing, pembeli), penjual tidak bisa chat dengan listingnya sendiri, "tertarik" unik, nomor WhatsApp tidak bocor di endpoint mana pun selain `/whatsapp`, batas 30 pesan per menit, peserta saja yang bisa membaca percakapan.

**Selesai jika:** skenario uji 1, 6, 9, dan 11 berjalan, termasuk pesan masuk secara realtime di dua perangkat atau emulator.

## M7 — Laporan, blokir, hukum

- [ ] **T7.1** Backend: `POST /reports`, `POST/DELETE /users/:id/block`, `GET /me/blocks`, penyaringan blokir pada kotak masuk dan pengiriman pesan.
- [ ] **T7.2** Flutter: bottom sheet laporan (listing, event, pengguna), "Blokir pengguna" di chat, Profile → Pengguna diblokir.
- [ ] **T7.3** Flutter: halaman Profile, Syarat Penggunaan, Kebijakan Privasi (`PRD.md` FR-15).
- [ ] **T7.4** Dokumentasikan skrip moderasi manual di README (rujuk `DATABASE.md` bagian 5).
- [ ] **T7.5** Tes: blokir menghalangi pesan, laporan tersimpan, listing `hidden` tidak muncul publik, akun dibekukan tidak bisa login.

**Selesai jika:** skenario uji 10 berjalan.

## M8 — Penyempurnaan, deploy, finalisasi

- [ ] **T8.1** Penyempurnaan UI: semua layar punya keadaan loading/kosong/error, pengecekan 360×740 dan skala teks 1,3, kontras, area sentuh, countdown per menit dengan satu timer bersama.
- [ ] **T8.2** Penanganan jaringan: tidak ada koneksi, token kedaluwarsa, gambar gagal dimuat, koneksi socket terputus.
- [ ] **T8.3** **Deploy** backend dan database ke server publik dengan HTTPS, folder unggahan persisten, `pg_dump` terjadwal, health check, dan variabel lingkungan produksi (rahasia tidak masuk repo).
- [ ] **T8.4** Bangun APK rilis bertanda tangan yang mengarah ke server publik.
- [ ] **T8.5** Jalankan seluruh skenario uji di `PRD.md` bagian 8 pada build rilis dan catat hasilnya.
- [ ] **T8.6** README lengkap (cara menjalankan, akun contoh, struktur, skrip moderasi), `.env.example`, `docs/DECISIONS.md` rapi.

## Bonus (hanya jika waktu sisa, urut prioritas)

1. "Tandai terjual kepada…" (pilih dari daftar chat) dan rating penjual
2. Peta mini di detail (OpenStreetMap, dengan atribusi)
3. Alert pencarian (efektif jika ada push)
4. Verifikasi nomor (OTP)
5. Panel admin web sederhana untuk laporan
6. Venue baru dengan pin peta
7. Lupa password
8. Push notification, **hanya setelah dosen memastikan solusi yang dipakai diperbolehkan**
