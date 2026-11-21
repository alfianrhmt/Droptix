-- Migration 006: Menghapus kategori wisata dan menyesuaikan urutan kategori
DELETE FROM categories WHERE slug = 'wisata';
UPDATE categories SET urutan = 4 WHERE slug = 'hiburan-lain';
