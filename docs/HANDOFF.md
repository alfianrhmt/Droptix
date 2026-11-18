# HANDOFF — Droptix

## Selesai
- **T7.1** selesai tuntas: Backend endpoints pelaporan dan pemblokiran (`POST /reports` dengan batas 10/hari dan validasi target, `POST/DELETE /users/:id/block` idempoten & anti-self-block, `GET /me/blocks`, serta filter blokir BR-12 pada inbox dan pesan).
- **T7.2** selesai tuntas: Flutter frontend untuk moderasi:
  - `ReportBottomSheet` (`features/moderation/report_bottom_sheet.dart`) untuk pelaporan listing, event, dan pengguna dengan 5 opsi alasan + keterangan + feedback SnackBar.
  - Integrasi "Laporkan" dan "Blokir pengguna" di `ChatScreen` dengan konfirmasi pemblokiran dan penguncian input chat jika pengguna diblokir.
  - Layar `BlockedUsersScreen` (`features/profile/blocked_users_screen.dart`) diakses dari Profile -> "Pengguna diblokir", menampilkan daftar terblokir dengan dialog konfirmasi unblock.
  - Pengujian: 6/6 widget tests di `test/moderation_test.dart` lulus (total 62/62 tests Flutter lulus, `flutter analyze` 0 issues, 129/129 tests Backend lulus).

## Sedang
- Menyiapkan **T7.3**: Flutter: halaman Profile, Syarat Penggunaan, Kebijakan Privasi (`PRD.md` FR-15).

## Langkah berikutnya
- **T7.3**: Implementasi layar Syarat Penggunaan dan Kebijakan Privasi statis di Profile (FR-15) beserta tautan pada pendaftaran jika diperlukan.
