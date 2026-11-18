# HANDOFF — Droptix

## Selesai
- **T7.1** selesai tuntas: Backend endpoints pelaporan dan pemblokiran (`POST /reports` dengan batas 10/hari dan validasi target, `POST/DELETE /users/:id/block` idempoten & anti-self-block, `GET /me/blocks`, serta filter blokir BR-12 pada inbox dan pesan).
- Pengujian: 129 backend tests (+14 pengujian baru di `reports_blocks.test.js`) lolos 100% dan `flutter analyze` 0 issues.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T7.2.

## Langkah berikutnya
- **T7.2**: Flutter: bottom sheet laporan (listing, event, pengguna), "Blokir pengguna" di chat, Profile → Pengguna diblokir.
