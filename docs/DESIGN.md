# DESIGN.md — Droptix

Brief desain untuk agen. Baca bersama `PRD.md`. Jika ada konflik: `PRD.md` menang untuk **fitur**, file ini menang untuk **tampilan**.

---

## 1. Gaya dan prinsip

Droptix adalah aplikasi agregator tiket resell (mobile, Flutter, **dark mode saja**).

- **Gaya visual: MTix.** Gelap, glow teal di background, poster jadi bintang, sudut membulat besar, navigasi bawah datar.
- **Struktur halaman dan informasi: TicketSwap.** Kolom search lebar penuh, pintasan tanggal, baris listing dengan thumbnail, halaman detail dengan kotak statistik.
- **Referensi** ada di `/docs/reference/` (lihat bagian 12). Ambil **gaya dan struktur** saja. Jangan menyalin logo, poster, ikon, atau aset apa pun dari MTix maupun TicketSwap.

Prinsip:
1. Poster-first: gambar event menarik perhatian lebih dulu, teks mengikuti.
2. Satu warna aksen (teal) ditambah satu warna urgensi (merah). Tidak ada warna lain sebagai dekorasi.
3. Hierarki jelas: judul, info penting (waktu, harga, jumlah), info pendukung.
4. Tenang dan bersih. Jangan ramai, jangan berlebihan.
5. Semua teks antarmuka berbahasa Indonesia.

**Dilarang** (bagian dari aturan anti-slop):
- efek kaca, blur, atau `BackdropFilter`
- gradasi pada tombol, kartu, atau teks (gradasi hanya untuk background global)
- warna kuning atau emas, warna ikon kategori yang berbeda-beda
- bayangan (drop shadow) tebal, glow neon, animasi berlebihan
- emoji sebagai ikon, lorem ipsum, teks marketing generik
- layar atau fitur di luar `PRD.md`

---

## 2. Design tokens

Semua token didefinisikan **sekali** di satu tempat (mis. `lib/core/theme/`). Layar dan widget **tidak boleh** menulis warna, ukuran font, padding, atau radius secara langsung.

### Warna

| Token | Nilai | Pemakaian |
|---|---|---|
| `bg` | `#010101` | dasar background |
| `glowMid` | `#0D262B` | glow teal (tengah) |
| `glowEnd` | `#103138` | glow teal (paling kuat) |
| `surface` | `#121518` | bottom nav, bar |
| `surfaceHigh` | `#26292C` | pil lokasi, kolom input, search |
| `chipInactive` | `#3B3B3B` | chip tidak aktif |
| `primary` | `#6CE6DB` | aksen: ikon aktif, tombol utama, link, jumlah tiket |
| `onPrimary` | `#062B28` | teks di atas `primary` |
| `outlineTeal` | `#649F99` | garis tepi tombol ikon |
| `iconButtonFill` | `#111D1C` | isi tombol ikon |
| `textPrimary` | `#FFFFFF` | teks utama |
| `textSecondary` | `#919294` | teks pendukung |
| `urgent` | `#EC626F` | tanggal/countdown, error, label Last-Minute |
| `success` | `#02CC66` | diskon |
| `divider` | putih 12% | garis pemisah, border kartu |

Nilai diperoleh dari sampel tangkapan layar referensi, jadi perkiraan. Boleh disetel sedikit asal tetap dalam keluarga warna yang sama dan **diubah di satu tempat saja**.

### Tipografi

Font: **Poppins** (paket `google_fonts`). Hanya dua bobot: 400 dan 600.

| Gaya | Ukuran / tinggi baris | Bobot |
|---|---|---|
| `titleLarge` | 22 / 28 | 600 |
| `titleMedium` | 18 / 24 | 600 |
| `body` | 15 / 22 | 400 |
| `bodySmall` | 13 / 18 | 400 |
| `label` | 14 / 20 | 600 |
| `caption` | 12 / 16 | 400 |

### Jarak, radius, elevasi

- **Jarak** (kelipatan 4): 4, 8, 12, 16, 24, 32. Padding horizontal layar: 16.
- **Radius:** 12 (elemen kecil), 16 (input, thumbnail, tombol ikon), 20 (poster, banner, kartu besar), pil penuh (chip, tombol utama, pil lokasi).
- **Elevasi:** tanpa bayangan. Beda tingkat ditunjukkan dengan warna permukaan atau border 1px (`divider`).
- **Area sentuh** minimal 48dp.
- **Ikon:** satu set saja (Material Icons versi rounded/outlined), warna mengikuti token.

---

## 3. Background global (`AppBackground`)

Satu widget yang membungkus semua layar. `Scaffold` dibuat transparan di atasnya.

- Dasar `bg`, lalu gradasi diagonal dari kiri atas ke kanan bawah: area kiri atas tetap gelap, glow `glowMid` muncul sekitar 40-45% ke bawah dan menguat jadi `glowEnd` di kanan bawah.
- Glow harus halus dan tidak mengurangi keterbacaan teks. Tidak ada blur.
- Bottom navigation berdiri di atas background dengan warna `surface`.

---

## 4. Komponen bersama (`lib/core/widgets/`)

Buat semuanya **sebelum** layar mana pun.

**AppHeader.** Logo wordmark "Droptix" di kiri, pil lokasi di kanan (ikon pin, nama kota, panah kecil, `surfaceHigh`, tinggi 40). Header statis, tanpa efek saat scroll.

**SearchBar.** Lebar penuh di bawah header, tinggi 48, `surfaceHigh`, radius 16, ikon kaca pembesar. Placeholder: "Cari artis, event, tempat…".

**BannerCarousel.** Rasio sekitar 2:1, radius 20, banner berikutnya sedikit mengintip dari tepi. Diketuk membuka pencarian dengan kata kunci event. Beri tampilan cadangan jika tidak ada gambar.

**SectionHeader.** Judul (`titleMedium`) dan tautan teks "Lihat semua" berwarna `primary` di kanan. **Tidak boleh** berupa tombol bulat berwarna.

**ResellTypeTiles.** Dua kotak berdampingan, "Limited" dan "Last-Minute" (tinggi 72, radius 16, border `outlineTeal`, isi `iconButtonFill`). Tiap kotak berisi judul (`label`) dan satu baris `caption` `textSecondary`: Limited "Tiket langka, cepat habis", Last-Minute "Lebih murah, acara segera mulai". Diketuk membuka pencarian dengan filter jenis tersebut.

**QuickDateGrid.** Grid 2×2: "Hari ini", "Besok", "Akhir pekan", "Lihat semua". Tombol outline (tinggi 52, radius 16, border `outlineTeal` 60%), teks `label`, ikon kalender `primary` di kanan.

**CategoryRow.** Baris yang bisa digeser horizontal berisi tombol ikon: kotak 64×64, radius 16, isi `iconButtonFill`, border `outlineTeal`, ikon `primary`, label 12 `textSecondary` di bawahnya. Kategori: Konser & Festival, Bioskop, Olahraga, Wisata, Hiburan Lain.

**PosterCard** (Home, carousel "Dekat Kamu"). Lebar sekitar 150, rasio 2:3, radius 20. Chip kecil semi-transparan (hitam 55%, tanpa blur) di bagian bawah poster. Di bawah poster: judul huruf kapital (`label`, maksimal 2 baris), venue dan jarak (`caption`, `textSecondary`), harga (`label`).

**ListingRow** (hasil pencarian, kategori, Activity). Satu baris tinggi sekitar 96:
- kiri: thumbnail poster 72×72, radius 16
- tengah: judul (`label`, 1 baris, elipsis); venue dan kota dengan jarak (`bodySmall`, `textSecondary`); baris info berisi ikon kalender dan waktu/countdown berwarna `urgent`, ikon tiket dan "2 tiket" berwarna `primary`
- kanan: harga (`label`) dan ikon bintang favorit (kosong, terisi `primary` jika disimpan)
- tanpa garis pemisah, jarak antar baris 12-16

**FilterChipRow.** Baris chip yang bisa digeser: "Tanggal ▾", "Urutkan ▾", "Lokasi ▾", "Jenis ▾", "Harga ▾", "Tersedia". Chip tinggi 40, pil penuh. **Aktif:** isi putih, teks hitam. **Tidak aktif:** `chipInactive`, teks putih.

**Badge.**
- `CountdownBadge`: warna `urgent`. Kurang dari 3 jam: "2j 15m lagi". Hari ini: "Hari ini 19.30". Selain itu: "Sab, 14 Feb". Perbarui per menit dengan **satu** timer bersama.
- `TypeBadge`: Limited (outline `primary`), Last-Minute (teks `urgent`, isi `urgent` 15%).
- Chip netral abu: Digital / Fisik, seksi tiket.
- Diskon: teks `success`, mis. "-40%".

**BottomNav.** 4 item: Home, Activity, Sell, Profile. Warna `surface`, tinggi 64 ditambah safe area. Aktif: ikon terisi dan label `primary`. Tidak aktif: `textSecondary`. Tanpa pil indikator. Ikon Activity dapat menampilkan `UnreadBadge` (bagian 9b).

**PrimaryButton.** Pil penuh, tinggi 52, isi `primary`, teks `onPrimary` (`label`). Variasi sekunder: outline `outlineTeal`.

**StatsCard.** Kotak dengan border `divider`, radius 20, tiga kolom: angka (`titleLarge`) dan label (`caption`, `textSecondary`).

**Keadaan kosong, loading, error.** Skeleton sederhana (tanpa shimmer berat), keadaan kosong berisi ikon, satu kalimat, dan satu tombol aksi. Poster cadangan per kategori: permukaan gelap dengan ikon kategori `primary`.

---

## 5. Halaman Home

Urutan dari atas: `AppHeader`, `SearchBar`, `BannerCarousel` (event ramai), `ResellTypeTiles`, `QuickDateGrid`, `CategoryRow`, carousel "Dekat Kamu" (`PosterCard`), section "Segera Berakhir" (`ListingRow`), section "Baru Ditambahkan" (`ListingRow`, scroll tanpa batas), `BottomNav`.

Maksimal 5 banner. Bioskop dan Wisata ditampilkan sebagai "terdekat". Kategori lain mengikuti event paling ramai.

## 6. Halaman Pencarian dan kategori

`FilterChipRow` di bawah judul halaman, lalu daftar `ListingRow`. Saat hasil kosong: "Belum ada tiket untuk '…'" dengan tombol "Jual tiketmu". Menampilkan 5 pencarian terakhir saat kolom search difokuskan.

## 7. Halaman Detail listing

Urutan dari atas (tanpa halaman event terpisah, ini halaman **listing**):
1. Bar atas: panah kembali, menu titik tiga (berisi "Laporkan listing").
2. Poster di tengah (lebar sekitar 55% layar, radius 20).
3. Judul event huruf kapital di tengah (`titleLarge`).
4. Baris tanggal/countdown (`urgent`, ikon kalender) dan baris venue (ikon pin).
5. Baris aksi: Favorit dan Bagikan.
6. `StatsCard`: **Tersedia / Terjual / Tertarik**.
7. Detail tiket (baris label-nilai): seksi, tipe, harga per tiket, harga asli (dicoret) dan persen selisih, jumlah, satuan atau paket, terikat nama, cara serah terima.
8. Lokasi: venue, kota, jarak. Untuk tiket fisik tampilkan area penjual saja.
9. Catatan penjual.
10. Foto tiket dari penjual (galeri), dengan peringatan kecil tentang QR.
11. Penjual: nama dan tanggal bergabung. "Diperbarui 2 jam lalu".
12. Banner disclaimer kecil: transaksi di luar tanggung jawab platform.
13. **Tombol tetap di bawah:** `PrimaryButton` "Chat dengan penjual" (menjadi "Buka chat" jika percakapan sudah ada; nonaktif untuk listing milik sendiri, atau yang terjual atau kedaluwarsa jika belum ada percakapan).

Tidak ada "Wanted", "Going", atau peringatan tiket (alert) seperti di TicketSwap.

## 8. Halaman Sell

Stepper 5 langkah dengan indikator kemajuan di atas, lalu halaman pratinjau. Kolom input: isi `surfaceHigh`, radius 16, label di atas kolom, pesan error berwarna `urgent` di bawah kolom. Tombol "Lanjut" di bawah. Langkah 5 memuat sakelar **"Izinkan lanjut via WhatsApp"** (mati secara default) dengan satu kalimat penjelasan bahwa nomor hanya terlihat oleh pembeli yang sudah memulai chat.

## 9. Halaman Activity

Tiga segmen bergaya `FilterChipRow` (aktif putih): **Selling**, **Saved**, **Chats**. Selling dan Saved berisi `ListingRow` dengan badge status (Tersedia, Terjual, Kedaluwarsa). Chats berisi `ConversationRow` (bagian 9b). Di segmen Selling ada aksi cepat: ubah jumlah terjual, "Tandai terjual semua", "Konfirmasi masih tersedia".

## 9b. Chat, laporan, dan Profile

Komponen berikut juga masuk `lib/core/widgets/` dan ditampilkan di Component Gallery.

**UnreadBadge.** Lingkaran minimal 18dp, isi `urgent`, angka putih (`caption`, bobot 600). Dipakai di ikon Activity, segmen Chats, dan `ConversationRow`. Tampilkan "9+" untuk angka di atas 9.

**ConversationRow** (Activity → Chats). Tinggi sekitar 80: thumbnail poster 56×56 radius 16; nama lawan bicara (`label`) dengan waktu (`caption`, `textSecondary`) di kanan atas; judul event (`bodySmall`, `textSecondary`, 1 baris); cuplikan pesan terakhir (`bodySmall`, 1 baris, putih dan bobot 600 jika belum dibaca); `UnreadBadge` di kanan bawah. Kosong: ikon, "Belum ada percakapan", tombol "Cari tiket".

**ChatListingCard.** Kartu ringkas di bawah AppBar chat: border `divider`, radius 16, poster 40×56 radius 12, judul (1 baris), harga per tiket, badge status. Diketuk membuka detail listing.

**ChatBubble.** Pesan sendiri rata kanan, isi `primary` dengan teks `onPrimary`. Pesan lawan rata kiri, isi `surfaceHigh` dengan teks putih. Radius 16, sudut yang dekat pengirim 4. Lebar maksimal 75%. Waktu (`caption`) ditampilkan per kelompok pesan, bukan per bubble. Pemisah tanggal ("Hari ini", "Kemarin").

**ChatInput.** Bar bawah `surface`; kolom `surfaceHigh` berbentuk pil, tinggi menyesuaikan hingga 4 baris, maksimal 1000 karakter; tombol kirim berupa ikon `primary` (nonaktif jika kosong). Status kirim: "Mengirim…" dan, jika gagal, ikon coba lagi berwarna `urgent`.

**Layar chat.** AppBar: panah kembali, nama lawan bicara, menu titik tiga berisi "Lanjut via WhatsApp" (hanya jika diizinkan penjual dan pengguna pembeli), "Laporkan", "Blokir pengguna". Di bawahnya `ChatListingCard`, lalu daftar pesan, lalu `ChatInput`. Chat kosong menampilkan chip saran cepat bergaya chip filter: "Halo, masih tersedia?", "Boleh nego?", dan untuk tiket fisik "Bisa COD?"; mengetuknya mengisi kolom pesan. Jika diblokir, `ChatInput` diganti teks "Kamu tidak bisa mengirim pesan di percakapan ini."

**Laporan.** Bottom sheet `surface` dengan pilihan alasan (Penipuan, Tiket palsu, Spam, Tidak pantas, Lainnya), kolom keterangan opsional, dan `PrimaryButton` "Kirim laporan". Setelah terkirim, tampilkan snackbar singkat.

**Profile.** Daftar menu berbentuk baris (ikon, label, panah): Edit profil, Ganti password, Pengguna diblokir, Syarat Penggunaan, Kebijakan Privasi, Keluar. Syarat dan Kebijakan adalah halaman teks statis dengan `titleMedium` dan `body`.

## 10. Teks dan format

- Gunakan "kamu", ramah dan singkat. Tanpa kalimat marketing generik.
- Rupiah: `Rp 1.250.000`. Per tiket: `Rp 500.000 / tiket`.
- Tanggal: `Sab, 14 Feb, 19.00`. Jarak: `1,2 km`. Jumlah: `2 tiket`.
- Placeholder search: "Cari artis, event, tempat…".
- Disclaimer: "Transaksi dilakukan langsung antara pembeli dan penjual. Droptix tidak bertanggung jawab atas transaksi di luar aplikasi."
- Peringatan foto tiket: "Tutup QR, barcode, dan kode booking sebelum mengunggah."
- Placeholder chat: "Tulis pesan…". Inbox kosong: "Belum ada percakapan". Terblokir: "Kamu tidak bisa mengirim pesan di percakapan ini."
- Sakelar WhatsApp: "Izinkan lanjut via WhatsApp. Nomormu hanya terlihat oleh pembeli yang sudah memulai chat."

## 11. Data contoh (seed) untuk tampilan

Gunakan data yang terlihat nyata, bukan lorem ipsum: sekitar 12-15 listing dengan nama event fiktif yang terdengar wajar (mis. "Nada Senja Live in Surabaya"), venue Surabaya dan kota besar lain, harga rupiah realistis, campuran Limited dan Last-Minute, campuran digital dan fisik, beberapa dengan countdown di bawah 3 jam, dan sebagian dengan poster, sebagian memakai poster cadangan. Tanpa data yang realistis, desain yang bagus akan tampak kosong.

## 12. Referensi visual

Letakkan tangkapan layar di `/docs/reference/` dengan nama berikut:

| Berkas | Isi | Diambil untuk |
|---|---|---|
| `mtix-home.jpg` | Home MTix | background glow, header, banner, tombol ikon, nav |
| `mtix-home-scroll.jpg` | Home MTix saat discroll | **hanya** untuk melihat gaya header. Efek kaca **tidak** diikuti |
| `mtix-movies.jpg` | Daftar film MTix | kartu poster, chip filter, chip pada poster |
| `ticketswap-home.jpg` | Home TicketSwap | search lebar penuh, pintasan tanggal, struktur section |
| `ticketswap-explore.jpg` | Explore events TicketSwap | baris listing, chip filter, tata letak info |
| `ticketswap-detail.jpg` | Detail event TicketSwap | urutan halaman detail, `StatsCard` |

## 13. Cara bekerja dan kriteria penerimaan

**Urutan:**
1. Buat token, `AppBackground`, dan komponen bersama (bagian 2-4).
2. Tampilkan semuanya di satu layar **Component Gallery** dengan data contoh. **Berhenti dan tunggu persetujuan.**
3. Baru buat layar satu per satu, satu layar per tugas.

**Setiap layar harus:**
- hanya memakai token dan komponen bersama
- diperiksa pada ukuran 390×844 dan 360×740, serta dengan skala teks 1,3 tanpa teks meluap
- punya keadaan loading, kosong, dan error
- kontras teks memadai (target setara WCAG AA)
- menyertakan tangkapan layar sebagai bukti
- tidak menambah fitur atau layar di luar `PRD.md`

Commit sebelum setiap sesi perubahan UI.
