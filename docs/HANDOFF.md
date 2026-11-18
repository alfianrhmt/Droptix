# HANDOFF — Droptix

## Selesai
- **T4.3** selesai tuntas: Endpoint backend `GET /events/trending` sesuai aturan bisnis BR-6. Kategori `konser-festival`, `olahraga`, `hiburan-lain` menghasilkan banner tipe `event` dengan `skor_event = active_listings + 0.5 * convs_7d`. Kategori `bioskop` dan `wisata` menghasilkan banner tipe `nearest` berisi `ListingCard` terdekat (dilewati jika tanpa koordinat). Hasil diurutkan berdasarkan `categories.urutan` (maks 5). Semua tes backend (63/63) dan Flutter (16/16) lolos bersih, 0 analyzer issues.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T4.4.

## Langkah berikutnya
- **T4.4**: Flutter halaman pencarian dan kategori (chip filter, urutan, daftar `ListingRow`, 5 pencarian terakhir, keadaan kosong).
