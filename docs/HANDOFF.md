# HANDOFF — Droptix

## Selesai
- **T6.1** selesai tuntas: Endpoint backend chat lengkap (`GET /listings/:id/conversation`, `POST /listings/:id/conversations` atomik dengan pesan pertama, `GET /conversations`, `GET /conversations/:id`, `GET /conversations/:id/messages` berpaginasi `before`, `POST /conversations/:id/messages`, `POST /conversations/:id/read`, `GET /me/unread`). Menerapkan aturan BR-12 (sembunyikan percakapan dari blocker di inbox, tolak pesan dengan 403 `BLOCKED`), tolak penjual chat ke diri sendiri (403), tolak chat baru jika tiket tidak tersedia (409 `CONFLICT`), dan batas laju 30 pesan/menit (429 `RATE_LIMITED`). 94 backend tests dan 42 Flutter tests lulus sempurna.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T6.2.

## Langkah berikutnya
- **T6.2**: Backend: Socket.IO (`realtime/`) dengan autentikasi JWT, room per pengguna, event `message:new` dan `unread:update`.
