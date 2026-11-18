# HANDOFF — Droptix

## Selesai
- **T4.2** selesai tuntas: Implementasi skor relevansi BR-5 dengan bobot di `backend/src/config/relevance.js` (`last_minute`: jarak 0.45, waktu 0.35, harga 0.20; `limited`: jarak 0.15, waktu 0.25, harga 0.60), normalisasi ulang bobot saat tanpa koordinat pengguna (jarak 0, waktu + harga = 1.0), `sort=relevan` di `GET /listings`, dan tie-breaking `waktu_acara ASC, id DESC`. Semua pengujian backend (58/58) dan Flutter (16/16) lolos bersih, 0 analyzer issues.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T4.3.

## Langkah berikutnya
- **T4.3**: Backend `GET /events/trending` (BR-6, memakai jumlah percakapan baru 7 hari).
