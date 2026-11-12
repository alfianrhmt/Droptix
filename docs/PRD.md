# PRD.md — Droptix

Versi 1.0 · Proyek akhir mata kuliah Pemrograman Aplikasi.

File ini adalah sumber kebenaran untuk **fitur dan aturan bisnis**. Dokumen terkait: `DESIGN.md` (tampilan), `DATABASE.md` (skema), `API.md` (kontrak API), `AGENTS.md` (aturan kerja agen), `TASKS.md` (urutan pengerjaan). Jika ada konflik: PRD menang untuk fitur, `DESIGN.md` untuk tampilan, `API.md` dan `DATABASE.md` untuk detail teknis. Jika ada hal yang tidak tercakup, pilih solusi paling sederhana dan catat di `docs/DECISIONS.md`.

---

## 1. Ringkasan

Droptix adalah aplikasi mobile (Flutter) yang mengumpulkan informasi **tiket resell** (bioskop, konser, olahraga, wisata, dll.) di satu tempat, mirip papan jual-beli. Droptix **hanya mempertemukan** penjual dan pembeli:

- tidak ada pembayaran, escrow, atau verifikasi keaslian tiket
- isi tiket (QR, barcode, kode booking) **tidak disimpan** di aplikasi
- komunikasi lewat **chat teks di dalam aplikasi**; WhatsApp hanya opsional jika penjual mengizinkan
- transaksi dan keamanan menjadi tanggung jawab penjual dan pembeli, seperti jual-beli di media sosial

**Ekspektasi.** Aplikasi harus unik, bernilai jual, dan terasa siap dipakai, bukan sekadar tugas. Pembeda utama: agregator tiket resell yang terstruktur, skor relevansi berdasarkan jarak, waktu, dan harga, listing yang jujur (kedaluwarsa otomatis, tanpa pre-order), dan chat yang terintegrasi.

## 2. Masalah dan tujuan

**Masalah.** Tiket resell tersebar di X, Threads, Instagram, dan grup WhatsApp. Sulit dicari berdasarkan lokasi atau waktu, informasinya tidak terstruktur, dan banyak postingan yang sudah basi (tiket sudah terjual atau acara sudah lewat).

**Tujuan.**
1. Satu tempat terstruktur untuk menemukan tiket resell.
2. Pencarian berdasarkan event, lokasi, waktu, dan harga.
3. Informasi ketersediaan yang jujur: tersedia, terjual, tertarik.
4. Ringan dan cepat dipakai, termasuk oleh penjual yang terburu-buru.
5. Dapat dipercaya dan siap dipakai: chat terintegrasi, laporan dan blokir, syarat dan privasi, serta berjalan di server publik.

**Bukan tujuan (v1).** Pembayaran dan escrow, verifikasi keaslian tiket, panel admin (laporan ditinjau lewat database), kategori transportasi, fitur pre-order/"wanted", notifikasi push (menunggu konfirmasi dosen soal FCM), lupa password.

## 3. Pengguna dan jenis resell

**Peran:** *Tamu* (hanya melihat) dan *Pengguna* (satu akun bisa menjual dan membeli).

**Dua jenis resell** (atribut setiap listing):

| | Limited | Last-Minute |
|---|---|---|
| Contoh | konser besar yang cepat habis | tiket bioskop, wisata, acara yang segera mulai |
| Harga | sering di atas harga asli | biasanya di bawah harga asli |
| Penjual | cari untung dari tiket langka | tidak bisa hadir atau salah beli, tidak mau mubazir |
| Pembeli | rela bayar lebih karena langka | cari yang murah dan dekat |
| Yang diutamakan | harga dan ketersediaan | jarak dan sisa waktu |

## 4. Ruang lingkup

| Wajib (P0) | Bonus (P1, hanya jika waktu sisa) | Di luar scope |
|---|---|---|
| Akun dan sesi, lokasi, event, listing (buat/lihat/ubah/hapus), stok, kedaluwarsa otomatis, Home, pencarian dengan filter dan urutan, skor relevansi, detail, **chat teks dalam aplikasi** (kotak masuk, badge belum dibaca, opsi WhatsApp), favorit, "tertarik" (dari chat), Activity, profil, **laporan dan blokir**, **halaman Syarat dan Privasi**, **deploy ke server publik** | Lupa password, peta mini di detail, venue baru dengan pin peta, "tandai terjual kepada…" dan rating penjual, alert pencarian, verifikasi nomor (OTP), panel admin web sederhana | Pembayaran dan escrow, verifikasi keaslian tiket, penyimpanan QR, transportasi, pre-order/"wanted", push notification (menunggu konfirmasi dosen), gambar di chat, multi-bahasa, iOS |

Kategori tetap (diisi lewat seed, penjual tidak bisa membuat kategori): **Konser & Festival, Bioskop, Olahraga, Wisata, Hiburan Lain**.

---

## 5. Fitur dan kriteria penerimaan

### FR-1 Akun dan sesi
- Registrasi: nama, email, password (minimal 8 karakter), dan persetujuan **Syarat Penggunaan dan Kebijakan Privasi** (wajib dicentang). Kota dan no. WhatsApp opsional saat daftar. **Kota wajib terisi sebelum memposting listing**; no. WhatsApp hanya wajib jika penjual mengaktifkan opsi WhatsApp (FR-6).
- Login menghasilkan JWT (7 hari) yang disimpan di penyimpanan aman. Sesi bertahan setelah aplikasi ditutup. Token kedaluwarsa mengarahkan ke login.
- Tamu bisa membuka Home, pencarian, dan detail. Aksi **Sell, Activity, favorit, Chat, Profile** meminta login, lalu kembali ke aksi semula setelah berhasil.
- Edit profil (nama, no. WhatsApp, kota), ganti password, logout.
- Akun yang dibekukan pengelola (`banned_at` terisi) tidak bisa login dan listingnya disembunyikan.

### FR-2 Lokasi
- Saat pertama dibuka, minta izin lokasi. Jika diberikan, koordinat dikirim sebagai parameter permintaan. Jika ditolak atau GPS mati, tampilkan layar pilih kota manual. Pilihan kota disimpan di perangkat.
- Koordinat pengguna **tidak disimpan di server**.
- Pil lokasi di header menampilkan nama kota dan bisa diganti.
- Tanpa koordinat: jarak tidak ditampilkan, urutan "Terdekat" disembunyikan, dan bagian "Dekat Kamu" menampilkan listing di kota terpilih yang diurutkan berdasarkan waktu acara.

### FR-3 Home
Urutan dan sumber data (lihat `DESIGN.md` untuk tampilan):
1. **Banner event ramai** dari `GET /events/trending` (maks. 5). Diketuk membuka pencarian dengan nama event sebagai kata kunci.
2. **Jenis resell** (Limited, Last-Minute): membuka pencarian dengan filter jenis.
3. **Pintasan tanggal** (Hari ini, Besok, Akhir pekan, Lihat semua): membuka pencarian dengan filter tanggal.
4. **Kategori**: membuka pencarian dengan filter kategori.
5. **Dekat Kamu**: `GET /listings?sort=terdekat&max_km=20`, atau berdasarkan kota jika tidak ada koordinat.
6. **Segera Berakhir**: `GET /listings?dalam_jam=24&sort=segera`.
7. **Baru Ditambahkan**: `GET /listings?sort=terbaru` dengan scroll tanpa batas (pagination).

Diterima jika setiap section menampilkan keadaan loading, kosong, dan error, dan section kosong tidak merusak tata letak.

### FR-4 Pencarian dan filter
- Kata kunci dicari pada nama event, nama venue, dan kota.
- **Filter:** kategori, jenis (Limited/Last-Minute), tipe (digital/fisik), kota, jarak maksimum (5/10/20 km/semua), rentang harga, tanggal (hari ini/besok/akhir pekan/tanggal pilihan), "hanya tersedia" (aktif secara default).
- **Urutan:** Relevan (default), Terdekat, Termurah, Paling segera, Terbaru.
- 5 pencarian terakhir disimpan di perangkat dan tampil saat kolom search difokuskan.
- Hasil kosong menampilkan "Belum ada tiket untuk '…'" dengan tombol "Jual tiketmu".

### FR-5 Detail listing
Menampilkan semua informasi di `DESIGN.md` bagian 7. Aturan:
- **Email dan nomor WhatsApp tidak pernah muncul di layar maupun di respons detail.** Tombol utama adalah "Chat dengan penjual" (FR-10).
- Statistik: Tersedia, Terjual, Tertarik.
- Listing yang sudah terjual atau kedaluwarsa tetap bisa dibuka lewat Activity dengan label status. Percakapan baru tidak bisa dimulai, tetapi percakapan yang sudah ada tetap bisa dibaca dan dibalas.
- Tampilkan "Diperbarui … lalu" berdasarkan waktu konfirmasi terakhir.

### FR-6 Menjual tiket (Sell)
Alur 5 langkah dengan indikator kemajuan, lalu pratinjau, lalu posting. Wajib login dan wajib punya kota di profil.

1. **Event dan kategori:** kategori, event (cari/pilih atau tambah baru, FR-7), jenis resell (default disarankan: Bioskop memilih Last-Minute, Konser & Festival memilih Limited, bisa diubah).
2. **Detail tiket dan waktu:** venue (pilih dari daftar, atau "Venue lainnya" dengan teks bebas dan kota), tanggal dan jam acara (harus di masa depan), tipe (digital/fisik), seksi/kelas (disarankan), nomor kursi (opsional). Jika fisik: kota/area penjual (dari GPS atau pilihan manual).
3. **Harga dan jumlah:** harga jual per tiket (> 0), harga asli per tiket (opsional), jumlah tiket (≥ 1), "Bisa dibeli satuan" atau "Ambil semua".
4. **Syarat dan serah terima:** terikat nama/KTP (Ya/Tidak/Tidak tahu). Cara serah terima: digital → transfer/kirim e-ticket; fisik → COD, ekspedisi, atau keduanya.
5. **Foto, kontak, catatan:** 1-3 foto (minimal 1) dengan peringatan menutup QR/barcode/kode booking, sakelar **"Izinkan lanjut via WhatsApp"** (mati secara default; jika dinyalakan, no. WhatsApp wajib ada di profil dan hanya terlihat oleh pembeli yang sudah memulai chat), catatan penjual (opsional).

Diterima jika: semua validasi di `API.md` berjalan dengan pesan error di bawah kolom, listing baru langsung tampil di Home/pencarian, dan tidak bisa membuat dua listing identik (event, venue, waktu, harga, penjual) dalam waktu dekat.

### FR-7 Event (pilih atau tambah)
- Event adalah data **bersama**: satu event dipakai banyak penjual. Untuk Bioskop, "event" adalah **judul film**; bioskop dan jam tayang disimpan di listing.
- Pencarian event menampilkan maksimal 10 hasil (poster kecil, nama, venue/tanggal bila ada), hanya event yang belum lewat atau masih punya listing aktif.
- Jika tidak ada: "Event tidak ditemukan? Tambah baru" dengan nama, venue/tanggal bila kategorinya berjadwal tetap, dan poster (opsional).
- Sebelum menyimpan, sistem memeriksa nama yang mirip dan menampilkan "Maksudmu ini?" (lihat `API.md`).
- Event langsung muncul tanpa persetujuan admin. Batas **5 event baru per akun per hari**. Event **terkunci** untuk diedit setelah ada listing dari penjual lain; hanya pembuatnya yang bisa mengedit sebelum itu.
- Poster: dipotong ke rasio 2:3 di aplikasi, diperkecil sebelum diunggah. Jika kosong, pakai poster cadangan per kategori.

### FR-8 Kelola listing (Activity → Selling)
- Daftar listing milik sendiri dengan status.
- Aksi: ubah jumlah terjual (stepper), "Tandai terjual semua", "Konfirmasi masih tersedia" (memperbarui waktu konfirmasi), edit, hapus (soft delete).
- Jumlah total tidak boleh di bawah jumlah terjual.

### FR-9 Favorit (Activity → Saved)
- Bintang di kartu, baris, dan detail menambah/menghapus favorit (butuh login). Tampil di Activity dengan status terbaru.

### FR-10 Chat dalam aplikasi
- Tombol utama di detail: **"Chat dengan penjual"** (wajib login). Jika sudah ada percakapan untuk pasangan (listing, pembeli), percakapan itu dibuka. Jika belum, layar chat kosong tampil dan percakapan baru **dibuat saat pesan pertama dikirim** (tidak ada percakapan kosong).
- Satu percakapan per pembeli per listing. Penjual tidak bisa memulai chat dengan listingnya sendiri. Percakapan **baru** hanya bisa dimulai pada listing berstatus `tersedia`; percakapan yang sudah ada tetap bisa dibaca dan dibalas walau listing sudah terjual atau kedaluwarsa.
- Pesan teks saja, 1-1000 karakter, tanpa gambar. Pesan terlama di atas, terbaru di bawah; riwayat dimuat per halaman saat digulir ke atas. Pesan tidak bisa diedit atau dihapus.
- Di atas layar chat ada kartu ringkas listing (poster kecil, judul, harga, status) yang bisa diketuk menuju detail.
- Pesan tampil seketika bagi penerima lewat **WebSocket di server sendiri**. Jika koneksi terputus, aplikasi menyambung ulang otomatis, dan saat layar chat terbuka memakai polling cadangan (tiap 5 detik) sampai tersambung kembali.
- **Kotak masuk:** Activity → segmen **Chats**. Tiap baris: poster kecil, nama lawan bicara, judul event, cuplikan pesan terakhir, waktu, dan badge jumlah pesan belum dibaca. Urut berdasarkan pesan terbaru.
- Saran pesan cepat pada chat kosong: "Halo, masih tersedia?", "Boleh nego?", dan untuk tiket fisik "Bisa COD?".
- "Tertarik" pada listing = jumlah pembeli unik yang memulai percakapan (BR-3).
- Batas 30 pesan per menit per pengguna.
- **Opsi WhatsApp:** jika `izinkan_wa` aktif pada listing, menu di layar chat menampilkan "Lanjut via WhatsApp" bagi pembeli, yang membuka tautan `wa.me` ke nomor penjual dengan pesan awal terisi. Nomor tidak pernah tampil di layar atau di detail listing.

### FR-11 Profil
Data akun, edit profil, ganti password, daftar pengguna yang diblokir, Syarat Penggunaan dan Kebijakan Privasi (FR-15), logout.

### FR-12 Status dan kedaluwarsa
Status **diturunkan**, tidak disimpan (lihat BR-1). Listing kedaluwarsa atau terjual tidak muncul di Home maupun pencarian publik (kecuali filter "hanya tersedia" dimatikan, yang menampilkan terjual tapi tidak kedaluwarsa), tetapi tetap tampil di Activity.

### FR-13 Laporan dan blokir
- Dari detail listing, detail event, profil penjual, dan layar chat tersedia **"Laporkan"** dengan alasan (Penipuan, Tiket palsu, Spam, Tidak pantas, Lainnya) dan keterangan opsional. Laporan disimpan dengan status `baru`.
- **Blokir pengguna** dari layar chat. Pengguna yang diblokir tidak bisa mengirim pesan kepada pemblokir, dan percakapan itu disembunyikan dari kotak masuk pemblokir. Blokir bisa dibatalkan di Profile → Pengguna diblokir.
- Peninjauan laporan pada v1 dilakukan **lewat database** oleh pengelola (tidak ada panel admin). Tindakannya: sembunyikan listing atau event (`hidden = true`) atau bekukan akun (`banned_at`). Skrip SQL ringkas ada di `DATABASE.md` bagian 5.

### FR-14 Notifikasi dalam aplikasi
- Ikon Activity di navigasi bawah menampilkan **badge jumlah percakapan yang belum dibaca**; segmen Chats menampilkan badge per percakapan.
- Tidak ada push notification pada v1 (menunggu konfirmasi dosen apakah FCM/Firebase diperbolehkan). Aplikasi memperbarui jumlah belum dibaca lewat WebSocket, dan memeriksa ulang saat dibuka serta tiap 60 detik selama aktif.

### FR-15 Syarat dan privasi
- Halaman statis **Syarat Penggunaan** dan **Kebijakan Privasi** di Profile. Isi minimal: peran Droptix (hanya mempertemukan, tanpa jaminan keaslian tiket), larangan (penipuan, tiket palsu, spam), data yang dikumpulkan (nama, email, kota, no. WhatsApp opsional, isi chat; lokasi hanya untuk menghitung jarak dan tidak disimpan), cara melapor, dan cara meminta penghapusan akun (ditangani manual lewat kontak pengelola pada v1).
- Persetujuan dicentang saat registrasi.

---

## 6. Aturan bisnis

**BR-1 Status listing (diturunkan):**
- `dihapus`: `deleted_at` terisi
- `kedaluwarsa`: `waktu_acara` ≤ sekarang
- `terjual`: `jumlah_total − jumlah_terjual` ≤ 0
- `tersedia`: selain itu

**BR-2 Stok.** `jumlah_tersedia = jumlah_total − jumlah_terjual`. Hanya penjual yang mengubahnya. Tidak ada reservasi otomatis.

**BR-3 Tertarik.** Jumlah "tertarik" = jumlah pembeli unik yang memulai percakapan pada listing itu (satu percakapan per pasangan listing dan pembeli).

**BR-4 Kerahasiaan kontak.** Email dan no. WhatsApp tidak pernah tampil di API publik. No. WhatsApp penjual hanya keluar lewat `POST /conversations/:id/whatsapp`, hanya untuk pembeli peserta percakapan, dan hanya jika `izinkan_wa` aktif.

**BR-5 Skor relevansi** (urutan "Relevan"). Setiap komponen bernilai 0-1:

```
S_jarak = 1 − min(jarak_km, 20) / 20
S_waktu = 1 − min(sisa_jam, 48) / 48          (sisa_jam = jam menuju waktu_acara)
S_harga = harga_min_event / harga              (harga_min_event = harga terendah di antara SEMUA
                                                listing aktif pada event yang sama, bukan hanya hasil terfilter)
skor    = w_jarak·S_jarak + w_waktu·S_waktu + w_harga·S_harga
```

| Jenis | w_jarak | w_waktu | w_harga |
|---|---|---|---|
| Last-Minute | 0,45 | 0,35 | 0,20 |
| Limited | 0,15 | 0,25 | 0,60 |

- Jika pengguna tidak punya koordinat: buang komponen jarak dan normalisasi ulang bobot sisanya agar berjumlah 1.
- Jika pengguna punya koordinat tetapi listing tidak punya titik acuan: `S_jarak = 0`.
- Hasil seri diurutkan `waktu_acara` naik, lalu `id` turun.
- Bobot disimpan sebagai konstanta di satu tempat agar mudah disetel.

**BR-6 Event ramai** (banner Home). `skor_event = jumlah listing aktif + 0,5 × jumlah percakapan baru dalam 7 hari terakhir`. Untuk kategori Konser & Festival, Olahraga, dan Hiburan Lain: ambil event dengan skor tertinggi (minimal punya satu listing aktif). Untuk Bioskop dan Wisata: banner "terdekat", yaitu listing aktif terdekat dari pengguna (dilewati jika tidak ada koordinat). Maksimal 5 banner, kategori tanpa data dilewati.

**BR-7 Titik acuan jarak.** Listing digital memakai koordinat venue. Listing fisik memakai koordinat penjual. Disalin ke `ref_lat` dan `ref_lng` saat listing dibuat atau diubah. Jarak dihitung dengan rumus Haversine.

**BR-8 Serah terima.** Digital hanya boleh `transfer_eticket`. Fisik boleh `cod` dan/atau `ekspedisi` (minimal satu).

**BR-9 Format tampilan.** Rupiah `Rp 1.250.000`, harga per tiket `Rp 500.000 / tiket`. Waktu disimpan UTC, ditampilkan WIB (Asia/Jakarta), format `Sab, 14 Feb, 19.00`. Jarak `1,2 km`.

**BR-10 Countdown.** Kurang dari 3 jam: "2j 15m lagi". Hari ini: "Hari ini 19.30". Lainnya: tanggal. Perbarui per menit dengan satu timer bersama.

**BR-11 Batas.** Foto per listing 1-3, ukuran unggahan maksimal 2 MB setelah diperkecil, 5 event baru per akun per hari, pesan chat 1-1000 karakter dan maksimal 30 pesan per menit per pengguna.

**BR-12 Chat dan blokir.** Satu percakapan per pasangan (listing, pembeli), dibuat saat pesan pertama dikirim. Jika salah satu pihak memblokir yang lain, tidak ada pesan baru dari pihak yang diblokir dan percakapan disembunyikan dari kotak masuk pemblokir. Pesan tidak bisa diedit atau dihapus.

---

## 7. Non-fungsional

- **Keamanan:** password di-hash (bcrypt), semua query berparameter, validasi input di server, pemeriksaan kepemilikan untuk ubah/hapus, validasi tipe dan isi berkas unggahan, batas laju request, tanpa rahasia di repo. WebSocket diautentikasi dengan JWT; keanggotaan percakapan dan blokir diperiksa di server.
- **Performa:** daftar listing dengan pagination (20 per halaman); respons pencarian wajar pada data demo (ratusan listing).
- **Platform:** Android lebih dulu. iOS tidak wajib.
- **Lokalisasi:** Bahasa Indonesia, zona waktu WIB.
- **Aksesibilitas dasar:** kontras teks memadai, area sentuh minimal 48dp, mendukung skala teks 1,3×.
- **Deploy:** backend dan database berjalan di server publik dengan HTTPS, folder unggahan persisten, backup database harian (cukup `pg_dump` terjadwal), dan health check. Aplikasi dirilis sebagai APK rilis bertanda tangan.

## 8. Skenario uji utama (juga untuk demo video)

1. Tamu membuka Home, mencari "film", membuka detail; menekan "Chat dengan penjual" lalu diarahkan login.
2. Registrasi, login, izin lokasi ditolak, memilih kota manual.
3. Penjual membuat event baru, sistem menampilkan "Maksudmu ini?" untuk nama mirip.
4. Penjual memposting listing Last-Minute (digital) lewat 5 langkah.
5. Pembeli mencari dengan filter Hari ini + jenis Last-Minute dan melihat urutan Relevan berubah saat lokasi berbeda.
6. Pembeli mengirim pesan pertama: "tertarik" bertambah 1. Mengirim lagi pada listing yang sama membuka percakapan yang sama (tetap 1).
7. Penjual mengubah jumlah terjual menjadi sama dengan total: listing berstatus Terjual dan hilang dari Home.
8. Listing yang waktu acaranya lewat otomatis hilang dari pencarian.
9. Penjual dan pembeli saling berbalas pesan secara realtime; badge belum dibaca muncul lalu hilang setelah percakapan dibuka.
10. Pembeli melaporkan sebuah listing; penjual memblokir pembeli dan pembeli tidak bisa lagi mengirim pesan.
11. Penjual mengaktifkan opsi WhatsApp; pembeli melihat "Lanjut via WhatsApp" hanya di dalam chat.

## 9. Keterbatasan (dicatat untuk laporan)

Tidak ada verifikasi keaslian tiket atau penjual; tidak ada reservasi stok; listing bisa basi jika penjual lupa memperbarui (dimitigasi dengan kedaluwarsa otomatis, "Diperbarui … lalu", dan "Konfirmasi masih tersedia"); event dibuat penjual tanpa moderasi di muka (hanya laporan dan peninjauan manual); tanpa push notification, pesan baru hanya terlihat saat aplikasi dibuka.

## 10. Pengembangan lanjutan

Kategori transportasi, panel admin dan moderasi otomatis, push notification, gambar di chat, rating penjual, alert pencarian, pembayaran aman (escrow, dicoba lewat sandbox gateway pembayaran), verifikasi penjual, PostGIS dan rekomendasi personal, halaman event yang mengelompokkan semua listing.
