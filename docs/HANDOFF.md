# HANDOFF — Droptix

## Selesai
- **M7 (Laporan, blokir, hukum) selesai tuntas 100%**:
  - **T7.1**: Backend endpoints pelaporan dan pemblokiran (`POST /reports` dengan batas 10/hari dan validasi target, `POST/DELETE /users/:id/block` idempoten & anti-self-block, `GET /me/blocks`, serta filter blokir BR-12 pada inbox dan pesan).
  - **T7.2**: Flutter frontend untuk moderasi: `ReportBottomSheet` untuk pelaporan listing, event, dan pengguna; integrasi di `ChatScreen` dan `ListingDetailScreen`; layar `BlockedUsersScreen` dengan konfirmasi unblock.
  - **T7.3**: Layar statis `TermsScreen` dan `PrivacyScreen` di Profile sesuai PRD.md FR-15 & DESIGN.md Bagian 9b, navigasi terhubung dari ProfileScreen.
  - **T7.4**: Dokumentasi lengkap skrip SQL moderasi manual di `README.md` (meninjau laporan, sembunyikan listing/event, bekukan akun pelanggar, selesaikan laporan).
  - **T7.5**: Verifikasi uji Skenario 10: pemblokiran menghalangi pesan (403 BLOCKED), laporan tersimpan, listing/event `hidden` tidak tampil di pencarian publik (404/terfilter), dan akun berstatus `banned_at` ditolak login maupun akses token.
- **T8.1 selesai tuntas**:
  - Audit dan pengujian komprehensif UI: seluruh layar memiliki state loading (`CircularProgressIndicator`), empty (`EmptyState`), dan error (`ErrorState` dengan tombol retry).
  - Responsivitas terverifikasi pada ukuran acuan **360×740 dp** dan **skala teks aksesibilitas 1.3** tanpa RenderFlex overflow.
  - Timer bersama `CountdownTimerProvider` mendetak sinkron per menit dan memperbarui seluruh `CountdownBadge`.
  - Area sentuh minimal 48×48 dp (`AppTouchTarget.min`) dipenuhi di seluruh komponen tombol dan menu.
  - Pengujian: 73/73 tests Flutter lulus (100%), `flutter analyze` 0 issues (bersih), 129/129 tests Backend lulus.

## Sedang
- Menyiapkan **T8.2**: Penanganan jaringan: tidak ada koneksi (offline mode), token kedaluwarsa (401 logout otomatis), gambar gagal dimuat (fallback placeholder), koneksi socket terputus (reconnect otomatis).

## Langkah berikutnya
- **T8.2**: Penguatan dan pengujian penanganan kegagalan jaringan & token kedaluwarsa.
- **T8.3**: Deploy backend dan database ke server publik dengan HTTPS.
