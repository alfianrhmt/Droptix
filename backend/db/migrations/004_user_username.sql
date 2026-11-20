-- Migration 004: Tambah username unik ke tabel users

ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(30);

-- Backfill jika ada user yang username-nya masih kosong
UPDATE users
SET username = LOWER(REGEXP_REPLACE(nama, '[^a-zA-Z0-9]', '', 'g')) || '_' || id
WHERE username IS NULL OR username = '';

ALTER TABLE users ALTER COLUMN username SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_unique ON users (LOWER(username));
