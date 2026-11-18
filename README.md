# Droptix

Aplikasi agregator tiket resell — mobile-first (Flutter) dengan backend Express + PostgreSQL.

## Prasyarat

- [Docker](https://www.docker.com/) & Docker Compose
- [Flutter](https://flutter.dev/) ≥ 3.13
- Node.js ≥ 20 (untuk pengembangan backend tanpa Docker)

## Menjalankan backend

```bash
# Salin dan isi variabel lingkungan
cp .env.example .env

# Jalankan API + database
docker compose up -d

# Jalankan migrasi dan seed awal
cd backend
npm run migrate
npm run seed

# Cek health
curl http://localhost:3000/api/v1/health
```

## Menjalankan Flutter

```bash
cd app
flutter pub get
flutter run
```

## Struktur repo

```
Droptix/
├── app/          # Proyek Flutter
│   └── lib/
│       ├── core/
│       │   ├── theme/    # Token warna, tipografi, jarak, radius
│       │   └── widgets/  # Komponen bersama
│       └── features/     # Fitur per screen
├── backend/      # API Express
│   └── src/
│       └── index.js
├── docs/         # Dokumentasi proyek (PRD, DESIGN, TASKS, dll.)
├── docker-compose.yml
├── .env.example
└── README.md
```

## Skrip moderasi manual (tanpa panel admin)

Pada versi 1 (v1), moderasi dan peninjauan laporan dilakukan langsung oleh pengelola melalui basis data PostgreSQL (lihat juga `docs/DATABASE.md` bagian 5).

Untuk menjalankan query melalui Docker Compose:
```bash
docker compose exec postgres psql -U postgres -d droptix
```

### 1. Meninjau laporan yang belum diproses
```sql
-- Daftar seluruh laporan berstatus 'baru'
SELECT r.id, r.created_at, r.reporter_id, u.nama AS reporter_nama,
       r.target_type, r.target_id, r.alasan, r.keterangan
FROM reports r
JOIN users u ON u.id = r.reporter_id
WHERE r.status = 'baru'
ORDER BY r.created_at ASC;
```

### 2. Menyembunyikan listing atau event yang melanggar
```sql
-- Sembunyikan listing (tidak akan tampil di pencarian dan halaman publik)
UPDATE listings SET hidden = true, updated_at = now() WHERE id = :listing_id;

-- Sembunyikan event yang tidak valid atau terindikasi fiktif
UPDATE events SET hidden = true WHERE id = :event_id;
```

### 3. Membekukan akun pelanggar (banned) & menyembunyikan listingnya
```sql
-- Bekukan akun pengguna (otomatis memutus sesi login dan menolak token berikutnya)
UPDATE users SET banned_at = now() WHERE id = :user_id;

-- Sembunyikan seluruh listing aktif milik pengguna tersebut
UPDATE listings SET hidden = true, updated_at = now() WHERE seller_id = :user_id;
```

### 4. Menyelesaikan laporan
```sql
-- Tandai laporan telah ditinjau dan selesai ditindak
UPDATE reports SET status = 'selesai' WHERE id = :report_id;
```

## Akun contoh (hanya untuk pengembangan)

Password untuk semua akun contoh: `Droptix123!`

| Nama | Email | Kota | No. WhatsApp |
|---|---|---|---|
| Raka Pratama | `raka@droptix.dev` | Surabaya | `6281234567801` |
| Dina Larasati | `dina@droptix.dev` | Surabaya | `6281234567802` |
| Bagas Wijaya | `bagas@droptix.dev` | Jakarta | `6281234567803` |

