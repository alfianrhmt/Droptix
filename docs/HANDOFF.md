# HANDOFF — Droptix

## Selesai
- **M7 (Laporan, blokir, hukum) selesai tuntas 100%**:
  - **T7.1**: Backend endpoints pelaporan dan pemblokiran (`POST /reports` dengan batas 10/hari dan validasi target, `POST/DELETE /users/:id/block` idempoten & anti-self-block, `GET /me/blocks`, serta filter blokir BR-12 pada inbox dan pesan).
  - **T7.2**: Flutter frontend untuk moderasi: `ReportBottomSheet` untuk pelaporan listing, event, dan pengguna; integrasi di `ChatScreen` dan `ListingDetailScreen`; layar `BlockedUsersScreen` dengan konfirmasi unblock.
  - **T7.3**: Layar statis `TermsScreen` dan `PrivacyScreen` di Profile sesuai PRD.md FR-15 & DESIGN.md Bagian 9b, navigasi terhubung dari ProfileScreen.
  - **T7.4**: Dokumentasi lengkap skrip SQL moderasi manual di `README.md` (meninjau laporan, sembunyikan listing/event, bekukan akun pelanggar, selesaikan laporan).
  - **T7.5**: Verifikasi uji Skenario 10: pemblokiran menghalangi pesan (403 BLOCKED), laporan tersimpan, listing/event `hidden` tidak tampil di pencarian publik (404/terfilter), dan akun berstatus `banned_at` ditolak login maupun akses token.
  - **Kualitas**: 129/129 tests Backend lulus (100%), 65/65 tests Flutter lulus (100%), `flutter analyze` 0 issues (bersih).

## Sedang
- Bersiap memasuki **M8 — Penyempurnaan, deploy, finalisasi**:
  - **T8.1**: Penyempurnaan UI (loading/kosong/error di seluruh layar, cek 360x740 dan skala teks 1.3, kontras, area sentuh, countdown per menit dengan timer bersama).
  - **T8.2**: Penanganan jaringan (offline, token expired, gambar gagal dimuat, socket reconnect).
  - **T8.3**: Deploy backend & database ke server publik dengan HTTPS.

## Langkah berikutnya
- **T8.1**: Audit dan penguatan UI state (loading/kosong/error), responsivitas 360x740 & text scale 1.3.
