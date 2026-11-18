# HANDOFF — Droptix

## Selesai
- **T5.3** selesai tuntas: Segmen Activity **Saved** (`DESIGN.md` bagian 9 & `PRD.md` FR-9) menampilkan daftar listing favorit via `GET /me/favorites`, mendukung status badge (`showStatusBadge: true` untuk Tersedia, Terjual, Kedaluwarsa), penghapusan favorit seketika dengan aksi *Urungkan (Undo)* via SnackBar, navigasi langsung ke `ListingDetailScreen` pada tiap baris, dan `EmptyState` informatif dengan tombol aksi "Cari Tiket". Seluruh 42 Flutter tests dan 74 backend tests lulus sempurna. Milestone M5 resmi tuntas 100%!

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai M6 (T6.1 — Backend Chat dalam aplikasi).

## Langkah berikutnya
- **T6.1**: Backend: Percakapan dan pesan (`GET/POST /listings/:id/conversations`, `GET /conversations`, `GET/POST /conversations/:id/messages`, `POST /conversations/:id/read`, `GET /me/unread`, aturan BR-12, batas laju 30 pesan/menit).
