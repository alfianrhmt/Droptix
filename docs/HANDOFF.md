# HANDOFF — Droptix

## Selesai
- **T4.6** selesai tuntas: Pengujian lengkap filter, urutan, kedaluwarsa, dan skor relevansi BR-5 (dua listing dengan jarak berbeda, bobot berbeda per jenis). Skenario Uji 5 (urutan Relevan berubah wajar saat lokasi pembeli diganti Surabaya vs Jakarta) dan Skenario Uji 8 (listing yang waktu acaranya lewat otomatis hilang dari pencarian) telah terverifikasi penuh baik di backend (67/67 tes) maupun di Flutter widget tests (31/31 tes). Milestone M4 resmi selesai 100%.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai M5 (T5.1).

## Langkah berikutnya
- **T5.1**: Backend: `POST/DELETE /listings/:id/favorite`, `GET /me/favorites`.
