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

- **T8.2 selesai tuntas**:
  - Penanganan jaringan offline/timeout: pemetaan otomatis `connectionError` ke `NETWORK_ERROR` dan `timeout` ke `TIMEOUT` dengan pesan ramah bahasa Indonesia.
  - Penanganan token kedaluwarsa & akun dibekukan: interceptor `ApiClient` otomatis menghapus token dari `TokenStorage` dan memicu logout saat menerima respons 401 `UNAUTHORIZED` atau 403 `ACCOUNT_BANNED`.
  - Fallback gambar: `EventPoster` dan `BannerCarousel` memiliki poster cadangan bergradasi dengan ikon kategori saat URL gambar null/error.
  - Ketahanan socket chat: `ChatSocketService` memiliki auto-reconnect delay 2 detik hingga 10 percobaan, fallback polling setiap 5 detik di `ChatScreen`, dan pemutusan bersih saat logout.
  - Pengujian: 79/79 tests Flutter lulus (100%), `flutter analyze` 0 issues (bersih), 129/129 tests Backend lulus.

## Sedang
- Menyiapkan **T8.3**: Deploy backend dan database ke server publik dengan HTTPS, folder unggahan persisten, `pg_dump` terjadwal, health check, dan variabel lingkungan produksi.

## Langkah berikutnya
- **T8.3**: Verifikasi konfigurasi produksi backend & database (Docker Compose produksi, backup dump terjadwal, upload volume).
- **T8.4**: Konfigurasi build APK rilis bertanda tangan (`flutter build apk --release`).
