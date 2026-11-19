-- Droptix Migration 002: Tambah kolom foto_url pada tabel users
ALTER TABLE users ADD COLUMN IF NOT EXISTS foto_url TEXT;
