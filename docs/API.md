# API.md — Droptix

REST API untuk aplikasi Flutter. Baca bersama `PRD.md` (aturan bisnis) dan `DATABASE.md` (skema).

## 1. Konvensi

- **Base path:** `/api/v1`. JSON UTF-8. Port pengembangan: `3000`.
- **Auth:** header `Authorization: Bearer <jwt>`. Tingkat akses tiap endpoint: `[publik]`, `[login]`, `[pemilik]` (login dan pemilik data).
- **Field:** `snake_case`. **Uang:** integer rupiah. **Waktu:** ISO 8601 dengan offset (server menyimpan UTC). **ID:** integer.
- **Sukses:** `{ "data": ..., "meta": { ... } }` (`meta` hanya jika perlu).
- **Pagination:** `page` (default 1), `limit` (default 20, maks. 50). `meta`: `{ "page": 1, "limit": 20, "total": 134 }`.
- **Berkas unggahan** dikembalikan sebagai **path relatif** (`/uploads/abc.jpg`). Aplikasi menambahkan host API di depannya.
- **Error:**

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Data tidak valid",
             "details": [ { "field": "harga", "message": "Harga harus lebih dari 0" } ] } }
```

| HTTP | code |
|---|---|
| 401 | `UNAUTHORIZED` |
| 403 | `FORBIDDEN`, `EVENT_LOCKED`, `BLOCKED`, `ACCOUNT_BANNED` |
| 404 | `NOT_FOUND` |
| 409 | `CONFLICT`, `SIMILAR_EVENT_EXISTS` |
| 422 | `VALIDATION_ERROR` |
| 429 | `RATE_LIMITED` |

- **Rate limit:** 100 request/menit/IP secara umum, 10/menit untuk `/auth/*`.
- Validasi input dengan skema (zod) di setiap endpoint tulis. Pesan error berbahasa Indonesia.

---

## 2. Objek bersama

**ListingCard** (daftar, banner, Activity):

```json
{
  "id": 42,
  "event": { "id": 7, "nama": "Nada Senja Live in Surabaya", "poster_url": "/uploads/a1.jpg",
             "category": { "id": 1, "slug": "konser-festival", "nama": "Konser & Festival" } },
  "venue_nama": "Grand City Convention Hall",
  "kota": "Surabaya",
  "waktu_acara": "2026-11-14T19:00:00+07:00",
  "jenis": "last_minute",
  "tipe": "digital",
  "seksi": "CAT 2",
  "harga": 450000,
  "harga_asli": 600000,
  "diskon_persen": 25,
  "jumlah_tersedia": 2,
  "jumlah_terjual": 1,
  "tertarik": 7,
  "status": "tersedia",
  "jarak_km": 1.2,
  "diperbarui": "2026-11-12T08:30:00+07:00",
  "is_favorite": false
}
```

Catatan: `diskon_persen` bernilai `null` jika `harga_asli` kosong atau `harga ≥ harga_asli` (selisih di atas harga asli tidak ditampilkan sebagai diskon). `jarak_km` `null` jika koordinat pengguna atau titik acuan kosong. `is_favorite` hanya jika login (selain itu `false`).

**ListingDetail** = ListingCard ditambah:

```json
{
  "no_kursi": null,
  "izinkan_wa": false,
  "satuan": true,
  "terikat_nama": "tidak",
  "serah_terima": ["transfer_eticket"],
  "lokasi_penjual_kota": null,
  "catatan": "Tidak bisa hadir.",
  "photos": [ { "id": 1, "url": "/uploads/p1.jpg" } ],
  "venue": { "id": 3, "nama": "Grand City Convention Hall", "kota": "Surabaya",
             "alamat": "…", "lat": -7.26, "lng": 112.75 },
  "seller": { "id": 5, "nama": "Rina", "bergabung": "2026-09-01T10:00:00+07:00" },
  "confirmed_at": "2026-11-12T08:30:00+07:00",
  "created_at": "2026-11-12T08:00:00+07:00"
}
```
**Tidak pernah** memuat `no_wa` atau data sensitif pengguna.

---

## 3. Auth dan akun

### `POST /auth/register` [publik]
Body: `{ "nama", "email", "password", "setuju_syarat": true, "no_wa"?, "kota"? }`
Aturan: password ≥ 8 karakter, email unik (409 `CONFLICT` jika dipakai), `setuju_syarat` wajib `true` (422 jika tidak), `no_wa` dinormalisasi ke format `62…`.
Respons 201: `{ "data": { "token": "…", "user": { "id", "nama", "email", "no_wa", "kota" } } }`

### `POST /auth/login` [publik]
Body: `{ "email", "password" }` → 200 `{ "data": { "token", "user" } }`. Salah kredensial: 401 dengan pesan umum (jangan membedakan email atau password yang salah). Akun yang dibekukan (`banned_at` terisi): 403 `ACCOUNT_BANNED`.

### `GET /me` [login] → `{ "data": { "id", "nama", "email", "no_wa", "kota", "created_at" } }`
### `PUT /me` [login]
Body: `{ "nama"?, "no_wa"?, "kota"? }` → data pengguna terbaru.
### `PUT /me/password` [login]
Body: `{ "password_lama", "password_baru" }` → 200 `{ "data": { "ok": true } }`. Password lama salah: 422.

---

## 4. Data master

### `GET /categories` [publik]
→ `{ "data": [ { "id", "slug", "nama", "ikon", "urutan" } ] }` (urut `urutan`).

### `GET /venues` [publik]
Query: `q`?, `kota`?, `limit` (default 20). → `[ { "id", "nama", "kota", "alamat", "lat", "lng" } ]`. Pencarian `q` memakai nama venue.

### `GET /events` [publik]
Autocomplete pemilihan event. Query: `q`, `category` (slug)?, maks. 10 hasil.
Hanya event yang `hidden = false` **dan** (`tanggal` kosong, atau `tanggal > now()`, atau punya listing aktif).
→ `[ { "id", "nama", "poster_url", "category": {…}, "venue": {…}|null, "tanggal": …|null } ]`

### `POST /events` [login]
Body: `{ "category_id", "nama", "poster_url"?, "venue_id"?, "tanggal"?, "force"? }`
Aturan:
- nama 3-120 karakter; `tanggal` (jika ada) di masa depan.
- Kategori Konser & Festival dan Olahraga: `venue_id` dan `tanggal` wajib.
- **Nama mirip:** jika ada event pada kategori yang sama dengan `similarity ≥ 0.5` dan `force` bukan `true` → 409 `SIMILAR_EVENT_EXISTS`:

```json
{ "error": { "code": "SIMILAR_EVENT_EXISTS", "message": "Ada event yang mirip",
             "similar": [ { "id": 7, "nama": "Nada Senja Live in Surabaya", "poster_url": null } ] } }
```
Aplikasi menampilkan "Maksudmu ini?"; jika pengguna tetap membuat baru, kirim ulang dengan `"force": true`.
- Batas 5 event baru per akun per hari → 429 `RATE_LIMITED`.
Respons 201: objek event.

### `PUT /events/:id` [pemilik]
Body: `{ "nama"?, "poster_url"?, "venue_id"?, "tanggal"? }`. Hanya pembuat event. Jika sudah ada listing dari penjual lain → 403 `EVENT_LOCKED`.

### `GET /events/trending` [publik]
Query: `lat`?, `lng`?. Mengembalikan maksimal 5 banner (BR-6):

```json
{ "data": [
  { "type": "event",   "category_slug": "konser-festival", "event": { "id": 7, "nama": "…", "poster_url": "…" } },
  { "type": "nearest", "category_slug": "bioskop", "listing": { /* ListingCard */ } }
] }
```
Banner `nearest` dilewati jika tanpa `lat`/`lng`. Urut sesuai `categories.urutan`.

### `POST /uploads` [login]
`multipart/form-data`, field `file`. Hanya JPG/PNG/WebP, maks. 2 MB. Server memvalidasi **isi berkas** (bukan hanya ekstensi), memakai nama acak, dan menyimpan di folder unggahan yang disajikan statis di `/uploads/`.
→ 201 `{ "data": { "url": "/uploads/f3a9….jpg" } }`

---

## 5. Listing

### `GET /listings` [publik]
Pencarian, filter, dan urutan.

| Query | Arti |
|---|---|
| `q` | kata kunci: nama event, nama venue, kota |
| `category` | slug kategori |
| `jenis` | `limited` atau `last_minute` |
| `tipe` | `digital` atau `fisik` |
| `kota` | nama kota acara |
| `lat`, `lng` | lokasi pengguna (opsional, dipasangkan) |
| `max_km` | jarak maksimum (5, 10, 20); memerlukan `lat`/`lng` |
| `min_harga`, `max_harga` | rentang harga per tiket |
| `tanggal` | `hari_ini`, `besok`, `akhir_pekan`, atau `YYYY-MM-DD` (zona WIB) |
| `dalam_jam` | acara dimulai dalam N jam ke depan (mis. 24) |
| `tersedia` | default `true`. `false` ikut menampilkan listing terjual (tidak pernah yang kedaluwarsa) |
| `sort` | `relevan` (default), `terdekat`, `termurah`, `segera`, `terbaru` |
| `page`, `limit` | pagination |

Aturan:
- Hanya listing aktif (lihat `DATABASE.md`), kecuali `tersedia=false` yang menambahkan status `terjual`.
- `akhir_pekan`: Sabtu 00.00 sampai Minggu 23.59 WIB berikutnya; jika hari ini Sabtu/Minggu, mulai dari sekarang sampai Minggu 23.59.
- `sort=terdekat` tanpa `lat`/`lng` → 422. `sort=relevan` tanpa lokasi memakai bobot yang dinormalisasi ulang (BR-5).
- `sort=segera`: `waktu_acara` naik. `termurah`: `harga` naik. `terbaru`: `created_at` turun.
- Jika `max_km` dipakai, listing tanpa titik acuan dikecualikan.

Respons: `{ "data": [ListingCard], "meta": { page, limit, total } }`.

### `GET /listings/:id` [publik]
→ `{ "data": ListingDetail }`. Menampilkan listing berstatus apa pun selain `dihapus` (404 untuk yang dihapus). Menyertakan `status` sehingga aplikasi bisa menonaktifkan tombol.

### `POST /listings` [login]
Body:

```json
{
  "event_id": 7,
  "venue_id": 3, "venue_teks": null, "kota": "Surabaya",
  "waktu_acara": "2026-11-14T19:00:00+07:00",
  "jenis": "last_minute", "tipe": "digital",
  "seksi": "CAT 2", "no_kursi": null,
  "harga": 450000, "harga_asli": 600000,
  "jumlah_total": 2, "satuan": true,
  "terikat_nama": "tidak",
  "serah_terima": ["transfer_eticket"],
  "lokasi_penjual_kota": null, "lokasi_penjual_lat": null, "lokasi_penjual_lng": null,
  "catatan": "Tidak bisa hadir.",
  "izinkan_wa": false,
  "photos": ["/uploads/p1.jpg"]
}
```
Validasi (422 jika gagal):
- Pengguna harus punya `kota` di profil. Jika `izinkan_wa` = `true`, pengguna juga harus punya `no_wa` di profil.
- `event_id` ada dan tidak `hidden`. `waktu_acara` di masa depan.
- Salah satu dari `venue_id` atau `venue_teks` wajib; jika `venue_teks`, `kota` wajib.
- `harga` > 0; `harga_asli` (jika ada) > 0; `jumlah_total` ≥ 1.
- `serah_terima`: tipe `digital` → hanya `["transfer_eticket"]`; tipe `fisik` → subset tidak kosong dari `["cod","ekspedisi"]`.
- Tipe `fisik` → `lokasi_penjual_kota` wajib (koordinat opsional).
- `photos`: 1-3 path yang berasal dari `/uploads/`.
- `izinkan_wa` bertipe boolean (default `false`).
- Duplikat: penjual yang sama, event, venue, waktu, dan harga identik dalam 10 menit terakhir → 409 `CONFLICT`.
- Server mengisi `ref_lat`/`ref_lng` (BR-7), `confirmed_at`, dan status.
Respons 201: `{ "data": ListingDetail }`.

### `PUT /listings/:id` [pemilik]
Body sama dengan `POST` (field boleh sebagian). `jumlah_total` tidak boleh di bawah `jumlah_terjual`; `waktu_acara` tidak boleh di masa lalu; `updated_at` diperbarui.

### `PATCH /listings/:id/stock` [pemilik]
Body: `{ "jumlah_terjual": 2 }` (nilai absolut, `0 … jumlah_total`). → ListingDetail terbaru. Status `terjual` terbentuk otomatis.

### `POST /listings/:id/confirm` [pemilik]
Memperbarui `confirmed_at` dan `updated_at` ("Konfirmasi masih tersedia"). → `{ "data": { "confirmed_at": "…" } }`.

### `DELETE /listings/:id` [pemilik]
*Soft delete*. → 204.

---

## 6. Chat, favorit, blokir, laporan

Pesan dikirim lewat REST (validasi dan rate limit di satu tempat) lalu disiarkan ke penerima lewat WebSocket (bagian 10).

**Conversation:**

```json
{
  "id": 12,
  "listing": { "id": 42, "judul": "Nada Senja Live in Surabaya", "poster_url": "/uploads/a1.jpg",
               "harga": 450000, "status": "tersedia" },
  "lawan": { "id": 5, "nama": "Rina" },
  "peran": "pembeli",
  "pesan_terakhir": "Masih ada?",
  "waktu_pesan_terakhir": "2026-11-12T09:10:00+07:00",
  "belum_dibaca": 2,
  "izinkan_wa": false
}
```

`peran` adalah peran pengguna yang meminta (`pembeli` atau `penjual`). **Message:** `{ "id", "conversation_id", "sender_id", "isi", "created_at" }`.

### `GET /listings/:id/conversation` [login]
Percakapan milik pembeli untuk listing ini. 200 `{ "data": Conversation }`, atau 404 jika belum ada (aplikasi menampilkan layar chat kosong).

### `POST /listings/:id/conversations` [login]
Body: `{ "isi": "Halo, masih tersedia?" }`. Membuat percakapan **dan** pesan pertama secara atomik. Jika percakapan sudah ada, hanya menambahkan pesan.
Aturan:
- percakapan baru hanya untuk listing berstatus `tersedia` (409 `CONFLICT`)
- penjual tidak boleh memulai chat dengan listingnya sendiri (403 `FORBIDDEN`)
- penjual memblokir pembeli → 403 `BLOCKED`
- `isi` 1-1000 karakter (422), maksimal 30 pesan per menit per pengguna (429)

→ 201 `{ "data": { "conversation": Conversation, "message": Message } }`.

### `GET /conversations` [login]
Kotak masuk, urut `last_message_at` turun, berpagination. Percakapan yang pemblokirnya adalah pengguna yang meminta tidak ditampilkan. → `{ "data": [Conversation], "meta": {…} }`.

### `GET /conversations/:id` [peserta]
→ `{ "data": Conversation }`. Bukan peserta: 404.

### `GET /conversations/:id/messages` [peserta]
Query: `before` (id pesan; ambil yang lebih lama), `limit` (default 30, maks. 100). Urut `id` turun (aplikasi membaliknya untuk tampilan).
→ `{ "data": [Message], "meta": { "ada_lebih_lama": true } }`.

### `POST /conversations/:id/messages` [peserta]
Body: `{ "isi": "…" }`. Aturan yang sama dengan pesan pertama; 403 `BLOCKED` jika salah satu pihak memblokir yang lain. → 201 `{ "data": Message }`. Memperbarui `last_message_at` dan pratinjau, lalu menyiarkan `message:new` ke lawan bicara.

### `POST /conversations/:id/read` [peserta]
Menandai percakapan dibaca sampai sekarang. → `{ "data": { "belum_dibaca": 0, "chats_belum_dibaca": 3 } }`.

### `POST /conversations/:id/whatsapp` [peserta, hanya pembeli]
Hanya jika `izinkan_wa` aktif pada listing dan penjual punya `no_wa`; selain itu 403 `FORBIDDEN` ("Penjual tidak mengizinkan WhatsApp").
→ `{ "data": { "wa_url": "https://wa.me/6281234567890?text=…" } }`. Pesan awal: "Halo, saya {nama pembeli} dari Droptix, tertarik dengan tiket {nama event} ({tanggal dan jam})." (di-URL-encode). Nomor tidak muncul di tempat lain.

### `GET /me/unread` [login]
→ `{ "data": { "chats": 3 } }` (jumlah percakapan yang berisi pesan belum dibaca).

### Favorit
- `POST /listings/:id/favorite` [login] → 200 `{ "data": { "is_favorite": true } }` (idempoten)
- `DELETE /listings/:id/favorite` [login] → 200 `{ "data": { "is_favorite": false } }`

### Blokir
- `POST /users/:id/block` [login] → 200 `{ "data": { "blocked": true } }` (idempoten; memblokir diri sendiri: 422)
- `DELETE /users/:id/block` [login] → 200 `{ "data": { "blocked": false } }`
- `GET /me/blocks` [login] → `{ "data": [ { "id", "nama" } ] }`

### `POST /reports` [login]
Body: `{ "target_type": "listing" | "event" | "user", "target_id", "alasan": "penipuan" | "tiket_palsu" | "spam" | "tidak_pantas" | "lainnya", "keterangan"? }` → 201 `{ "data": { "id" } }`. Maksimal 10 laporan per hari per pengguna (429). Tidak ada antarmuka admin; peninjauan lewat database (`DATABASE.md` bagian 5).

---

## 7. Activity

Semua [login], berpagination, mengembalikan `ListingCard` dengan `status` apa pun (kecuali `dihapus`) agar aplikasi bisa menampilkan label.

- `GET /me/listings`: listing milik sendiri, `created_at` turun. Boleh `?status=tersedia|terjual|kedaluwarsa`.
- `GET /me/favorites`: favorit, terbaru dulu.
- Segmen **Chats** memakai `GET /conversations` (bagian 6).

---

## 8. Bonus (P1)

Kontrak untuk fitur P1 (tandai terjual kepada pembeli, rating, alert, OTP, lupa password, panel admin) belum dirinci. Rancang saat dikerjakan dan perbarui dokumen ini lebih dulu.

---

## 9. Catatan implementasi

- Skor relevansi (BR-5) dihitung di SQL pada `sort=relevan`. `harga_min_event` memakai subquery atas **semua** listing aktif pada event, bukan hanya hasil terfilter.
- Semua query memakai parameter, **tidak ada** penyambungan string SQL.
- Endpoint yang mengubah data memeriksa kepemilikan di server, bukan hanya di aplikasi.
- Gunakan CORS dan `helmet`. Jangan mencatat (log) token atau password.
- Pesan dikirim lewat REST dan hanya disiarkan lewat WebSocket. Keanggotaan percakapan dan blokir diperiksa di server pada setiap permintaan.
- Jangan mencatat isi pesan ke log.

---

## 10. WebSocket (Socket.IO)

Dipasang di server Express yang sama (path bawaan `/socket.io`). **Tidak memakai Firebase atau layanan realtime pihak ketiga.**

- **Autentikasi:** klien menyambung dengan `auth: { token: <jwt> }`. Token tidak valid atau akun dibekukan → `connect_error`.
- Server otomatis memasukkan koneksi ke room `user:{id}`.
- **Server → klien:**
  - `message:new` — `{ "message": Message, "conversation": { "id", "belum_dibaca" } }`, dikirim ke lawan bicara saat pesan baru tersimpan.
  - `unread:update` — `{ "chats": 3 }`, dikirim saat jumlah percakapan belum dibaca berubah.
- **Klien → server:** tidak ada. Pengiriman pesan dan penandaan dibaca selalu lewat REST.
- Klien membuka satu koneksi untuk seluruh aplikasi (saat login), menutupnya saat logout, menyambung ulang otomatis, dan memakai polling `GET /conversations/:id/messages` (tiap 5 detik, hanya saat layar chat terbuka) sebagai cadangan.
