-- Migration 005: Tabel banners promosi & etalase editorial home
CREATE TABLE IF NOT EXISTS banners (
  id SERIAL PRIMARY KEY,
  type VARCHAR(30) NOT NULL DEFAULT 'standard',
  badge VARCHAR(50),
  title VARCHAR(150) NOT NULL,
  subtitle TEXT,
  cta_label VARCHAR(50),
  target_type VARCHAR(50) NOT NULL,
  target_payload VARCHAR(100),
  image_url TEXT,
  gradient_colors TEXT[],
  urutan INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_banners_active_urutan ON banners (is_active, urutan ASC);
