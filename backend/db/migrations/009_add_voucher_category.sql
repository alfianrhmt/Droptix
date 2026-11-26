-- Migration 009: Tambahkan kategori baru 'Voucher' (urutan 4) dan geser 'hiburan-lain' ke urutan 5
UPDATE categories SET urutan = 5 WHERE slug = 'hiburan-lain';

INSERT INTO categories (slug, nama, ikon, urutan)
VALUES ('voucher', 'Voucher', 'local_offer', 4)
ON CONFLICT (slug) DO UPDATE
  SET nama = EXCLUDED.nama,
      ikon = EXCLUDED.ikon,
      urutan = EXCLUDED.urutan;
