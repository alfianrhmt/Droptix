# HANDOFF — Droptix

## Selesai
- **T6.4** selesai tuntas: Opsi WhatsApp di backend (`POST /conversations/:id/whatsapp`, validasi pembeli, cek BR-12, format tanggal WIB, URL `wa.me`) dan Flutter (item menu "Lanjut via WhatsApp" di `ChatScreen`, `url_launcher`, dan mockable `UrlLauncherFn`).
- Pengujian: 108 backend tests (+7 tes baru whatsapp) dan 54 Flutter widget/unit tests lulus 100% tanpa error analyzer.

## Sedang
- Menunggu konfirmasi `"lanjut"` dari pengguna sebelum memulai T6.5.

## Langkah berikutnya
- **T6.5**: Tes: satu percakapan per (listing, pembeli), penjual tidak bisa chat dengan listingnya sendiri, "tertarik" unik, nomor WhatsApp tidak bocor di endpoint mana pun selain `/whatsapp`, batas 30 pesan per menit, peserta saja yang bisa membaca percakapan.
