# HANDOFF — Droptix

## Selesai
- **T5.1** selesai tuntas: Endpoint favorit `POST /api/v1/listings/:id/favorite` (idempoten via `ON CONFLICT DO NOTHING`, guard 404 listing/seller tidak valid), `DELETE /api/v1/listings/:id/favorite`, dan `GET /api/v1/me/favorites` (terbaru dulu `f.created_at DESC`, pagination, kalkulasi jarak `lat`/`lng`, `is_favorite: true`). Seluruh 74 backend tests dan 31 Flutter tests lulus sempurna.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T5.2.

## Langkah berikutnya
- **T5.2**: Flutter: halaman detail (`DESIGN.md` bagian 7), label status, favorit, bagikan, tombol "Chat dengan penjual" (sementara membuka layar placeholder sampai M6 selesai).
