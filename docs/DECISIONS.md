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
| 10 | Alur Sell mengunggah foto langsung saat dipilih via `POST /uploads` sebelum posting final | Menghindari payload multipart raksasa di `POST /listings` dan memungkinkan pratinjau instan |
| 11 | `computeListingStatus()` mengembalikan `'dihapus'` untuk `deleted_at`/`hidden=true` sebagai internal guard | Status ini tidak masuk `API.md` publik; `GET /listings/:id` mengembalikan 404 untuk status ini. `GET /listings` publik (T4.1) WAJIB memfilter `deleted_at IS NULL AND hidden = false` di SQL, bukan mengandalkan status computed |
| 12 | Activity segmen Selling mengintegrasikan aksi cepat (ubah stok, terjual semua, konfirmasi, edit, hapus) langsung pada kartu listing | Memudahkan penjual mengelola ketersediaan tiket dari satu layar tanpa harus berpindah ke alur terpisah |
| 13 | Perhitungan rentang filter `tanggal` (`hari_ini`, `besok`, `akhir_pekan`, `YYYY-MM-DD`) di `getWibDateRange` berbasis zona waktu WIB (UTC+7) | Memastikan batas waktu filter tanggal seragam dan konsisten terlepas dari perbedaan zona waktu server backend atau pengguna |
| 14 | Bobot relevansi BR-5 dan generator klausa SQL `ORDER BY` dipusatkan di `backend/src/config/relevance.js` | Memastikan bobot mudah disetel di satu tempat dan formula relevansi konsisten antara kalkulasi SQL Postgres dan pengujian JavaScript |
| 15 | Banner trending BR-6 membagi kategori menjadi tipe `event` (`konser-festival`, `olahraga`, `hiburan-lain` dengan bobot percakapan 7 hari) dan `nearest` (`bioskop`, `wisata` dengan jarak Haversine terdekat) | Mengimplementasikan diferensiasi kebutuhan pengguna: acara besar diprioritaskan popularitasnya, sedangkan bioskop/wisata diprioritaskan kedekatan lokasinya |
| 16 | Penyimpanan 5 pencarian terakhir memakai `RecentSearchesStorage` via `SharedPreferences` (kunci `droptix_recent_searches`) dengan deduplikasi case-insensitive | Ringan, bekerja offline tanpa database lokal tambahan, dan otomatis memindahkan istilah pencarian aktif ke urutan pertama |
| 17 | Carousel horizontal "Dekat Kamu" menggunakan tinggi container 340px untuk menampung PosterCard rasio 2:3 (lebar 150) beserta teks judul 2 baris dan harga | Mencegah RenderFlex overflow pada layar sempit 360x740 dan skala teks dinamis |
| 18 | Pengujian Skenario 5 & 8 memverifikasi pembalikan urutan Relevan antara dua kota (Surabaya vs Jakarta) dan eliminasi listing yang waktu acaranya telah lewat | Memastikan formula skor relevansi BR-5 dan guard kedaluwarsa berfungsi akurat secara end-to-end baik di backend maupun antarmuka Flutter |
| 19 | Endpoint favorit menggunakan `ON CONFLICT DO NOTHING` pada `POST` (idempoten) dan menyertakan `is_favorite: true` secara eksplisit pada `GET /me/favorites` | Menjamin operasi penambahan favorit aman dipanggil berulang kali dan mempermudah rendering kartu tersimpan di sisi klien |
| 20 | Halaman detail listing tiket menyatukan 13 bagian DESIGN.md bagian 7, tombol chat dinonaktifkan untuk listing milik sendiri atau tiket tidak tersedia, serta membuka ChatPlaceholderScreen sebelum M6 | Memenuhi aturan privasi FR-5 (tanpa kontak langsung di antarmuka), menjaga konsistensi hak aksi pengguna, dan memberi transisi mulus menuju fitur chat M6 |
| 21 | Segmen Activity Saved menampilkan ListingRow dengan status badge (Tersedia, Terjual, Kedaluwarsa), un-favorite optimistik dengan opsi Urungkan (Undo), dan EmptyState beraksi kembali ke Home | Memberikan pengalaman mengelola tiket tersimpan yang cepat dan toleran terhadap kesalahan pengguna tanpa kehilangan konteks navigasi |
| 22 | Pembuatan chat pertama di `POST /listings/:id/conversations` secara atomik membuat conversation dan pesan pertama, sedangkan `computeListingStatus` diekstraksi ke `backend/src/utils/status.js` | Mencegah dependensi sirkular antara route listings dan conversations, menjamin integritas percakapan hanya untuk tiket berstatus 'tersedia' (409 bila tidak), dan mengizinkan pesan lanjutan jika chat sudah ada |




