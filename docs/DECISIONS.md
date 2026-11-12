# DECISIONS.md — Droptix

Catatan keputusan desain yang tidak tercakup di dokumen utama. Format: satu baris — apa, kenapa.

| # | Keputusan | Alasan |
|---|---|---|
| 1 | Seed placeholder di T0.1 (hanya log, tidak insert data) | Data seed lengkap dikerjakan di T1.2 sesuai urutan TASKS.md; seed memerlukan skema DB yang baru dibuat di T1.1 |
| 2 | `main.dart` menampilkan layar preview token sementara | T0.2 hanya token dan AppBackground; layar nyata dan navigasi (go_router) dikerjakan mulai T0.3 |
| 3 | iOS, linux, macos, web, windows folder diabaikan di .gitignore | AGENTS.md: Android dulu, iOS tidak wajib, platform lain di luar scope |
| 4 | Skrip `migrate` melacak migrasi di tabel `schema_migrations` | Membuat migrasi idempoten dan tiap file `.sql` dijalankan atomik dalam satu transaksi |

