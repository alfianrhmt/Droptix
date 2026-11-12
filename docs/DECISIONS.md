# DECISIONS.md — Droptix

Catatan keputusan desain yang tidak tercakup di dokumen utama. Format: satu baris — apa, kenapa.

| # | Keputusan | Alasan |
|---|---|---|
| 1 | Seed placeholder di T0.1 (hanya log, tidak insert data) | Data seed lengkap dikerjakan di T1.2 sesuai urutan TASKS.md; seed memerlukan skema DB yang baru dibuat di T1.1 |
| 2 | `main.dart` menampilkan layar preview token sementara | T0.2 hanya token dan AppBackground; layar nyata dan navigasi (go_router) dikerjakan mulai T0.3 |
| 3 | iOS, linux, macos, web, windows folder diabaikan di .gitignore | AGENTS.md: Android dulu, iOS tidak wajib, platform lain di luar scope |
| 4 | Skrip `migrate` melacak migrasi di tabel `schema_migrations` | Membuat migrasi idempoten dan tiap file `.sql` dijalankan atomik dalam satu transaksi |
| 5 | Memakai `bcryptjs` (pure JS) untuk hash password | Menghindari kendala kompilasi native di Windows dan Alpine Docker |
| 6 | Memakai `shared_preferences` untuk penyimpanan token sesi & `API_BASE_URL` via `--dart-define` (default `http://10.0.2.2:3000/api/v1`) | Sederhana tanpa setup keystore tambahan di Windows/emulator serta mudah di-mock di widget/unit test |
| 7 | Validasi isi berkas unggahan (`POST /uploads`) memeriksa magic bytes JPG/PNG/WebP langsung dengan `multer` memoryStorage | Ringan, bebas masalah kompatibilitas ESM/native, dan tidak bergantung pada ekstensi berkas klien |
| 8 | Pemetaan koordinat GPS ke nama kota memakai jarak Haversine terhadap daftar kota Indonesia di `cities.dart` | Berjalan seragam di Android, Web, dan Windows tanpa plugin reverse-geocoding eksternal |
| 9 | Crop poster rasio 2:3 di Flutter memakai `InteractiveViewer` + `RepaintBoundary.toImage()` | Berjalan lintas platform (Android, Web, Windows) tanpa konfigurasi native UCrop/cropperjs |

