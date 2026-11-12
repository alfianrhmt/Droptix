# DATABASE.md — Droptix

PostgreSQL 16. Skema di bawah dipakai sebagai migrasi awal (`backend/db/migrations/001_init.sql`). Nama tabel dan kolom memakai `snake_case`. Uang disimpan sebagai **integer rupiah**. Semua waktu `timestamptz` (UTC).

---

## 1. Skema

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE users (
  id            SERIAL PRIMARY KEY,
  nama          VARCHAR(80)  NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  password_hash TEXT         NOT NULL,
  no_wa         VARCHAR(20),                 -- format 62xxxxxxxxxx
  kota          VARCHAR(60),
  setuju_syarat_at TIMESTAMPTZ NOT NULL DEFAULT now(),  -- persetujuan syarat dan privasi
  banned_at     TIMESTAMPTZ,                 -- diisi pengelola untuk membekukan akun
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  id      SERIAL PRIMARY KEY,
  slug    VARCHAR(30) NOT NULL UNIQUE,       -- konser-festival, bioskop, olahraga, wisata, hiburan-lain
  nama    VARCHAR(60) NOT NULL,
  ikon    VARCHAR(40) NOT NULL,              -- nama ikon di aplikasi
  urutan  INT         NOT NULL
);

CREATE TABLE venues (
  id        SERIAL PRIMARY KEY,
  nama      VARCHAR(120) NOT NULL,
  kota      VARCHAR(60)  NOT NULL,
  alamat    TEXT,
  lat       DOUBLE PRECISION,
  lng       DOUBLE PRECISION
);
CREATE INDEX idx_venues_kota ON venues (kota);
CREATE INDEX idx_venues_nama_trgm ON venues USING gin (nama gin_trgm_ops);

CREATE TABLE events (
  id          SERIAL PRIMARY KEY,
  category_id INT          NOT NULL REFERENCES categories(id),
  nama        VARCHAR(120) NOT NULL,
  nama_normal VARCHAR(120) NOT NULL,         -- lower(trim(nama)), spasi ganda dirapikan
  poster_url  TEXT,                          -- path relatif, mis. /uploads/abc.jpg
  venue_id    INT REFERENCES venues(id),     -- boleh kosong (mis. film)
  tanggal     TIMESTAMPTZ,                   -- boleh kosong (mis. film, wisata)
  created_by  INT          NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  hidden      BOOLEAN      NOT NULL DEFAULT false
);
CREATE INDEX idx_events_category ON events (category_id);
CREATE INDEX idx_events_nama_trgm ON events USING gin (nama_normal gin_trgm_ops);

CREATE TABLE listings (
  id              SERIAL PRIMARY KEY,
  event_id        INT NOT NULL REFERENCES events(id),
  seller_id       INT NOT NULL REFERENCES users(id),

  venue_id        INT REFERENCES venues(id),
  venue_teks      VARCHAR(120),              -- dipakai jika "Venue lainnya"
  kota            VARCHAR(60) NOT NULL,      -- kota acara
  waktu_acara     TIMESTAMPTZ NOT NULL,

  jenis           VARCHAR(12) NOT NULL CHECK (jenis IN ('limited','last_minute')),
  tipe            VARCHAR(8)  NOT NULL CHECK (tipe IN ('digital','fisik')),
  seksi           VARCHAR(60),
  no_kursi        VARCHAR(60),

  harga           INT NOT NULL CHECK (harga > 0),          -- per tiket
  harga_asli      INT CHECK (harga_asli > 0),              -- per tiket, opsional
  jumlah_total    INT NOT NULL CHECK (jumlah_total >= 1),
  jumlah_terjual  INT NOT NULL DEFAULT 0 CHECK (jumlah_terjual >= 0),
  satuan          BOOLEAN NOT NULL DEFAULT true,           -- true: bisa satuan, false: ambil semua

  terikat_nama    VARCHAR(10) NOT NULL CHECK (terikat_nama IN ('ya','tidak','tidak_tahu')),
  serah_terima    TEXT[] NOT NULL,                          -- transfer_eticket | cod | ekspedisi

  lokasi_penjual_kota VARCHAR(60),                          -- wajib jika tipe = 'fisik'
  lokasi_penjual_lat  DOUBLE PRECISION,
  lokasi_penjual_lng  DOUBLE PRECISION,

  ref_lat         DOUBLE PRECISION,          -- titik acuan jarak (BR-7), diisi aplikasi
  ref_lng         DOUBLE PRECISION,

  catatan         TEXT,
  izinkan_wa      BOOLEAN NOT NULL DEFAULT false,  -- lanjut via WhatsApp; nomor diambil dari users.no_wa
  hidden          BOOLEAN NOT NULL DEFAULT false,  -- disembunyikan pengelola (tindak lanjut laporan)

  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  CHECK (jumlah_terjual <= jumlah_total),
  CHECK (venue_id IS NOT NULL OR venue_teks IS NOT NULL)
);
CREATE INDEX idx_listings_event   ON listings (event_id);
CREATE INDEX idx_listings_seller  ON listings (seller_id);
CREATE INDEX idx_listings_waktu   ON listings (waktu_acara);
CREATE INDEX idx_listings_kota    ON listings (kota);
CREATE INDEX idx_listings_created ON listings (created_at DESC);

CREATE TABLE listing_photos (
  id         SERIAL PRIMARY KEY,
  listing_id INT  NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  url        TEXT NOT NULL,                  -- path relatif
  urutan     INT  NOT NULL DEFAULT 0
);

CREATE TABLE favorites (
  user_id    INT NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  listing_id INT NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, listing_id)
);

-- Chat. "Tertarik" = jumlah percakapan per listing (BR-3). Percakapan dibuat saat pesan pertama dikirim.
CREATE TABLE conversations (
  id                   SERIAL PRIMARY KEY,
  listing_id           INT NOT NULL REFERENCES listings(id),
  buyer_id             INT NOT NULL REFERENCES users(id),
  seller_id            INT NOT NULL REFERENCES users(id),   -- disalin dari listing saat dibuat
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message_at      TIMESTAMPTZ,
  last_message_preview VARCHAR(80),
  buyer_last_read_at   TIMESTAMPTZ,
  seller_last_read_at  TIMESTAMPTZ,
  UNIQUE (listing_id, buyer_id),
  CHECK (buyer_id <> seller_id)
);
CREATE INDEX idx_conv_buyer  ON conversations (buyer_id,  last_message_at DESC);
CREATE INDEX idx_conv_seller ON conversations (seller_id, last_message_at DESC);

CREATE TABLE messages (
  id              BIGSERIAL PRIMARY KEY,
  conversation_id INT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id       INT NOT NULL REFERENCES users(id),
  isi             TEXT NOT NULL CHECK (char_length(isi) BETWEEN 1 AND 1000),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_messages_conv ON messages (conversation_id, id DESC);

CREATE TABLE blocks (
  blocker_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE TABLE reports (
  id          SERIAL PRIMARY KEY,
  reporter_id INT NOT NULL REFERENCES users(id),
  target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('listing','event','user')),
  target_id   INT NOT NULL,
  alasan      VARCHAR(20) NOT NULL CHECK (alasan IN ('penipuan','tiket_palsu','spam','tidak_pantas','lainnya')),
  keterangan  TEXT,
  status      VARCHAR(10) NOT NULL DEFAULT 'baru' CHECK (status IN ('baru','ditinjau','selesai')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reports_status ON reports (status, created_at);
```

## 2. Ekspresi yang dipakai berulang

**Status listing (BR-1)** — dihitung di query, tidak disimpan:

```sql
CASE
  WHEN l.deleted_at IS NOT NULL OR l.hidden    THEN 'dihapus'
  WHEN l.waktu_acara <= now()                   THEN 'kedaluwarsa'
  WHEN l.jumlah_total - l.jumlah_terjual <= 0   THEN 'terjual'
  ELSE 'tersedia'
END
```

**Jarak Haversine (km)** antara titik pengguna (`:lat`, `:lng`) dan titik acuan listing:

```sql
6371 * 2 * asin(sqrt(
  power(sin(radians(l.ref_lat - :lat) / 2), 2) +
  cos(radians(:lat)) * cos(radians(l.ref_lat)) *
  power(sin(radians(l.ref_lng - :lng) / 2), 2)
))
```
Hasilnya `NULL` jika `ref_lat`/`ref_lng` kosong.

**Listing aktif** (tampil publik): `deleted_at IS NULL AND hidden = false AND waktu_acara > now() AND jumlah_total - jumlah_terjual > 0`, dan penjualnya tidak dibekukan (`users.banned_at IS NULL`).

**Tertarik per listing:** `SELECT count(*) FROM conversations WHERE listing_id = l.id`.

**Belum dibaca (untuk pengguna :uid):** percakapan yang `last_message_at` lebih baru dari `*_last_read_at` milik pengguna (atau `*_last_read_at` kosong) dan pesan terakhirnya bukan dikirim oleh pengguna itu. Kolom yang dipakai: `buyer_last_read_at` jika pengguna pembeli, `seller_last_read_at` jika penjual.

**Pengecekan nama event mirip:** `similarity(nama_normal, :nama_normal_baru) >= 0.5` pada kategori yang sama.

## 3. Aturan di lapisan aplikasi (bukan di database)

- `nama_normal`: huruf kecil, `trim`, spasi ganda dirapikan. Nama tampilan (`nama`) tidak diubah hurufnya.
- `ref_lat`/`ref_lng`: tipe `fisik` → koordinat penjual; tipe `digital` → koordinat venue; kosong jika tidak ada.
- `updated_at` diperbarui setiap perubahan oleh penjual; `confirmed_at` diperbarui saat "Konfirmasi masih tersedia" dan saat listing dibuat.
- Penghapusan listing adalah *soft delete* (`deleted_at`).
- Password tidak pernah keluar dari API. Email dan `users.no_wa` tidak keluar dari endpoint publik; no. WhatsApp hanya lewat `POST /conversations/:id/whatsapp`.
- Membuka percakapan memperbarui `buyer_last_read_at` atau `seller_last_read_at` milik pembukanya. Setiap pesan baru memperbarui `last_message_at` dan `last_message_preview`.
- Blokir: percakapan yang salah satu pesertanya memblokir yang lain disembunyikan dari kotak masuk pemblokir, dan pengiriman pesan dari pihak yang diblokir ditolak.

## 4. Data awal (seed)

Skrip seed (`backend/db/seed.js`) bersifat **idempoten** dan membuat:

1. **Kategori** (urutan ini):

| urutan | slug | nama |
|---|---|---|
| 1 | `konser-festival` | Konser & Festival |
| 2 | `bioskop` | Bioskop |
| 3 | `olahraga` | Olahraga |
| 4 | `wisata` | Wisata |
| 5 | `hiburan-lain` | Hiburan Lain |

2. **Venue** sekitar 25-30: bioskop dan pusat acara di Surabaya (mal, convention hall, stadion) ditambah beberapa venue besar di kota lain (mis. Jakarta, Bandung). **Koordinat harus diverifikasi lewat peta, jangan dikarang.** Jika ragu, isi `lat`/`lng` dengan `NULL` dan beri komentar.
3. **Pengguna contoh** 3 akun (hanya untuk pengembangan, password dicatat di README).
4. **Event contoh** 8-10, nama **fiktif tapi wajar** (bukan lorem ipsum, bukan event nyata), tersebar di kelima kategori. Beberapa tanpa poster agar poster cadangan teruji.
5. **Listing contoh** 15-20, dengan `waktu_acara` dihitung **relatif terhadap waktu seed dijalankan** (mis. `now() + interval '2 hours'`, `'1 day'`, `'3 days'`, `'3 weeks'`) supaya countdown, "Segera Berakhir", dan filter tanggal bisa dilihat. Campurkan: Limited dan Last-Minute, digital dan fisik, beberapa sebagian terjual, beberapa dengan harga di bawah dan di atas harga asli, dan beberapa dengan jumlah tiket lebih dari 1.
6. Beberapa percakapan (masing-masing beberapa pesan, sebagian belum dibaca) dan baris `favorites`, supaya angka "tertarik", kotak masuk, dan badge belum dibaca bisa dilihat.

Foto listing dan poster contoh disimpan sebagai berkas lokal kecil di `backend/uploads/seed/` (gambar buatan sendiri atau sumber bebas lisensi, bukan aset MTix/TicketSwap).

## 5. Skrip moderasi manual (tanpa panel admin)

Pada v1 laporan ditinjau langsung di database oleh pengelola.

```sql
-- Laporan yang belum ditinjau
SELECT * FROM reports WHERE status = 'baru' ORDER BY created_at;

-- Sembunyikan listing atau event
UPDATE listings SET hidden = true WHERE id = :id;
UPDATE events   SET hidden = true WHERE id = :id;

-- Bekukan akun dan sembunyikan semua listingnya
UPDATE users    SET banned_at = now() WHERE id = :id;
UPDATE listings SET hidden = true WHERE seller_id = :id;

-- Tandai laporan selesai
UPDATE reports  SET status = 'selesai' WHERE id = :id;
```
