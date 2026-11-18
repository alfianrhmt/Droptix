# HANDOFF — Droptix

## Status Proyek
Seluruh Milestone **M0 hingga M8** telah **selesai tuntas 100%** sesuai spesifikasi `PRD.md`, `DESIGN.md`, `DATABASE.md`, dan `API.md`.

## Ringkasan Pencapaian Milestone
- **M0 (Pondasi & Tooling)**: Docker Compose dev, Flutter skeleton, token desain & tema gelap.
- **M1 (Database, Master Data, Autentikasi)**: Migrasi PostgreSQL idempoten, seed 5 kategori & 30 venue, JWT auth, registrasi dengan persetujuan syarat.
- **M2 (Lokasi & Penjual)**: Deteksi GPS/Haversine, fallback kota manual, wizard posting 5 langkah, pembuatan event dengan similarity check.
- **M3 (Jelajah, Detail, Favorit)**: Home feed, banner trending, countdown per menit, detail tiket transparan (FR-5 tanpa leak kontak), sistem favorit.
- **M4 (Pencarian & Filter)**: Pencarian dengan bobot relevansi BR-5, filter tanggal WIB, jenis, harga, riwayat pencarian lokal.
- **M5 (Aktivitas & Manajemen Penjual)**: Layar Activity 3 segmen (Selling, Saved, Chats), aksi cepat stok/konfirmasi/hapus/edit.
- **M6 (Chat Realtime & Opsi WhatsApp)**: REST chat atomik, WebSocket Socket.IO room per pengguna, polling cadangan 5 detik, pengalihan WhatsApp privat.
- **M7 (Laporan, Blokir, Hukum)**: Pelaporan listing/event/user via `ReportBottomSheet`, pemblokiran dua arah BR-12, daftar pengguna diblokir, layar statis Syarat Penggunaan & Kebijakan Privasi, panduan skrip moderasi manual.
- **M8 (Penyempurnaan, Deploy, Finalisasi)**:
  - Responsivitas terverifikasi pada 360×740 dp dan skala teks 1.3 tanpa overflow (T8.1).
  - Penanganan jaringan offline/timeout dan auto-logout 401/403 (T8.2).
  - Stack produksi `docker-compose.prod.yml` dengan Caddy reverse proxy (HTTPS otomatis), volume unggahan persisten, healthcheck, dan backup harian terjadwal (`backup-db.sh`) (T8.3).
  - Konfigurasi build APK rilis bertanda tangan Android dengan `--dart-define=API_BASE_URL=...` dan permission `INTERNET` (T8.4).
  - 11 Skenario Uji `PRD.md` Bagian 8 tervalidasi 100% pada `docs/TEST_SCENARIOS_RESULT.md` (T8.5).
  - Dokumentasi lengkap di `README.md`, `DECISIONS.md`, dan `.env.example` (T8.6).

## Kualitas Kode & Hasil Uji
- **Backend**: 129/129 tests lolos 100% (`npm test`).
- **Flutter**: 79/79 tests lolos 100% (`flutter test`).
- **Linter**: `flutter analyze` 0 issues (`No issues found!`).
