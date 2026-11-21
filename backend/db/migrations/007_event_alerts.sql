-- Migration 007: Tabel event_alerts untuk notifikasi ketersediaan tiket event
CREATE TABLE IF NOT EXISTS event_alerts (
  id SERIAL PRIMARY KEY,
  event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_event_user_alert UNIQUE (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_alerts_event ON event_alerts (event_id, is_active);
CREATE INDEX IF NOT EXISTS idx_event_alerts_user ON event_alerts (user_id, is_active);
