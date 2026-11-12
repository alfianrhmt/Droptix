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

## Skrip moderasi (singkat)

Lihat `docs/DATABASE.md` bagian 5 untuk daftar query manual moderasi (blokir akun, hapus listing, dsb.).

## Akun contoh (hanya untuk pengembangan)

Password untuk semua akun contoh: `Droptix123!`

| Nama | Email | Kota | No. WhatsApp |
|---|---|---|---|
| Raka Pratama | `raka@droptix.dev` | Surabaya | `6281234567801` |
| Dina Larasati | `dina@droptix.dev` | Surabaya | `6281234567802` |
| Bagas Wijaya | `bagas@droptix.dev` | Jakarta | `6281234567803` |

