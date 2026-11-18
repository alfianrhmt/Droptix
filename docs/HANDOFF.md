# HANDOFF — Droptix

## Selesai
- **T7.1** selesai tuntas: Backend endpoints pelaporan dan pemblokiran (`POST /reports` dengan batas 10/hari dan validasi target, `POST/DELETE /users/:id/block` idempoten & anti-self-block, `GET /me/blocks`, serta filter blokir BR-12 pada inbox dan pesan).
- **T7.2** selesai tuntas: Flutter frontend untuk moderasi:
  - `ReportBottomSheet` (`features/moderation/report_bottom_sheet.dart`) untuk pelaporan listing, event, dan pengguna dengan 5 opsi alasan + keterangan + feedback SnackBar.
  - Integrasi "Laporkan" dan "Blokir pengguna" di `ChatScreen` dengan konfirmasi pemblokiran dan penguncian input chat jika pengguna diblokir.
  - Layar `BlockedUsersScreen` (`features/profile/blocked_users_screen.dart`) diakses dari Profile -> "Pengguna diblokir", menampilkan daftar terblokir dengan dialog konfirmasi unblock.
  - Pengujian: 6/6 widget tests di `test/moderation_test.dart` lulus (total 62/62 tests Flutter lulus, `flutter analyze` 0 issues, 129/129 tests Backend lulus).
- **T7.3** selesai tuntas: Layar statis Syarat Penggunaan (`TermsScreen`) dan Kebijakan Privasi (`PrivacyScreen`) di Profile sesuai PRD.md FR-15 dan DESIGN.md Bagian 9b, navigasi terhubung dari `ProfileScreen`, dan seluruh 3 widget test di `test/legal_screens_test.dart` lulus (total 65/65 Flutter tests lulus, `flutter analyze` 0 issues).

## Sedang
- Menyiapkan **T7.4**: Dokumentasikan skrip moderasi manual di README (rujuk `DATABASE.md` bagian 5).

## Langkah berikutnya
- **T7.4**: Dokumentasikan skrip moderasi manual di README (rujuk `DATABASE.md` bagian 5).
- **T7.5**: Tes terintegrasi: blokir menghalangi pesan, laporan tersimpan, listing `hidden` tidak muncul publik, akun dibekukan tidak bisa login.
