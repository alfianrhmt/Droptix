-- Migration 008: Tabel notifications untuk notifikasi in-app (tiket baru dari Pantau Tiket / event_alerts)
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(30) NOT NULL DEFAULT 'new_ticket',
  title VARCHAR(160) NOT NULL,
  body TEXT NOT NULL,
  event_id INT REFERENCES events(id) ON DELETE CASCADE,
  listing_id INT REFERENCES listings(id) ON DELETE SET NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, is_read)
  WHERE is_read = false;
