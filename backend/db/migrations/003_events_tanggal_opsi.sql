-- Migration 003: Tambah tanggal_opsi ke events dan perbarui nama kategori hiburan-lain menjadi Lainnya

ALTER TABLE events ADD COLUMN IF NOT EXISTS tanggal_opsi DATE[];

UPDATE events
SET tanggal_opsi = ARRAY[tanggal::date]
WHERE tanggal IS NOT NULL AND (tanggal_opsi IS NULL OR array_length(tanggal_opsi, 1) IS NULL);

UPDATE categories
SET nama = 'Lainnya'
WHERE slug = 'hiburan-lain';
