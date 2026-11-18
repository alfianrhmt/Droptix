# HANDOFF — Droptix

## Selesai
- **M6 (Chat dalam aplikasi)** selesai 100%: T6.1 s/d T6.5 tuntas.
- **T6.5** selesai tuntas: Pengujian komprehensif chat (1 percakapan per pasangan listing & pembeli, penjual dilarang chat listing sendiri [403], metrik "tertarik" unik [BR-3], leak audit nomor WA di seluruh endpoint & model, rate limit 30 msg/menit, dan isolasi akses 404 untuk non-peserta).
- Pengujian: 115 backend tests dan 56 Flutter widget/unit tests lulus 100% tanpa error analyzer.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai Milestone 7 (M7).

## Langkah berikutnya
- **M7 — Laporan, blokir, hukum**: T7.1 Backend: `POST /reports`, `POST/DELETE /users/:id/block`, `GET /me/blocks`, penyaringan blokir pada kotak masuk dan pengiriman pesan.
