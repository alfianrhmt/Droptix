# HANDOFF — Droptix

## Selesai
- **T4.1** selesai tuntas: Endpoint backend `GET /listings` dengan semua filter (`q`, `category`, `jenis`, `tipe`, `kota`, `min_harga`, `max_harga`, `dalam_jam`, `tanggal`, `max_km`, `tersedia`), urutan (`terdekat`, `termurah`, `segera`, `terbaru`, `relevan`), pagination, jarak Haversine, pengecekan kedaluwarsa (`waktu_acara > now()`), soft-delete, hidden, dan penjual dibekukan (`users.banned_at IS NULL`). Semua tes backend (52/52) dan Flutter (16/16) lolos bersih, 0 analyzer issues.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T4.2.

## Langkah berikutnya
- **T4.2**: Backend skor relevansi (BR-5) dengan bobot di satu berkas konfigurasi, `sort=relevan`, normalisasi ulang tanpa lokasi.
