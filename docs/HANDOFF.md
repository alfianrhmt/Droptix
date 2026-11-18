# HANDOFF — Droptix

## Selesai
- **T6.3** selesai tuntas: Implementasi fitur chat Flutter lengkap (`features/chat/` dengan `chat_models.dart`, `chat_repository.dart`, `chat_socket_service.dart`, `chat_screen.dart`). Mendukung koneksi socket tunggal seumur hidup sesi pengguna di `AppShell`, update badge `UnreadBadge` pada ikon navigasi Activity, segmen Activity **Chats** yang menampilkan `ConversationRow` (dan `EmptyState` dengan aksi "Cari Tiket" jika kosong), serta `ChatScreen` lengkap dengan `ChatListingCard`, `ChatBubble` (gaya pesan sendiri vs lawan), `DateSeparator`, saran cepat (`QuickReplyChips`), `ChatInput` (maks. 1000 karakter, indikator mengirim dan coba lagi), polling cadangan 5 detik, dan guard blokir. 101 backend tests dan 49 Flutter tests lulus sempurna (0 issues analyzer).

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T6.4.

## Langkah berikutnya
- **T6.4**: Backend dan Flutter: opsi WhatsApp (`POST /conversations/:id/whatsapp`, item menu "Lanjut via WhatsApp" di chat, hanya jika `izinkan_wa`).
