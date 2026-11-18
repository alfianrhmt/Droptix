# HANDOFF — Droptix

## Selesai
- **T6.2** selesai tuntas: Layanan realtime Socket.IO dipasang pada backend (`realtime/` dengan `auth.js`, `events.js`, `index.js`). Mendukung autentikasi handshake JWT (`auth: { token }`, penolakan token tak valid atau akun dibekukan `connect_error`), room otomatis per pengguna (`user:{id}`), penyiaran `message:new` (`{ message, conversation: { id, belum_dibaca } }`) ke lawan bicara pada `POST /listings/:id/conversations` dan `POST /conversations/:id/messages`, serta penyiaran `unread:update` (`{ chats }`) saat ada pesan baru atau percakapan dibaca (`POST /conversations/:id/read`). 101 backend tests dan 42 Flutter tests lulus sempurna.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T6.3.

## Langkah berikutnya
- **T6.3**: Flutter: koneksi socket tunggal (login/logout, sambung ulang otomatis), layar chat (kartu listing, bubble, input, saran pesan cepat, polling cadangan), Activity segmen **Chats** (`ConversationRow`), badge belum dibaca di ikon Activity.
