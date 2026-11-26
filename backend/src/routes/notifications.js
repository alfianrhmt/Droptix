'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');

const notificationIdParamSchema = z.object({
  id: z.coerce.number().int().positive('ID notifikasi tidak valid.'),
});

function formatNotificationRow(row) {
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    body: row.body,
    event_id: row.event_id ?? null,
    event_nama: row.event_nama ?? null,
    event_poster_url: row.event_poster_url ?? null,
    listing_id: row.listing_id ?? null,
    is_read: Boolean(row.is_read),
    created_at: row.created_at,
  };
}

/**
 * Router notifikasi in-app pengguna (/api/v1/notifications).
 */
function createNotificationsRouter(db, requireAuth) {
  const router = express.Router();

  router.get('/', requireAuth, async (req, res, next) => {
    try {
      const userId = req.user.id;
      const [listRes, countRes] = await Promise.all([
        db.query(
          `SELECT n.id, n.type, n.title, n.body, n.event_id, n.listing_id,
                  n.is_read, n.created_at,
                  e.nama AS event_nama, e.poster_url AS event_poster_url
           FROM notifications n
           LEFT JOIN events e ON e.id = n.event_id
           WHERE n.user_id = $1
           ORDER BY n.created_at DESC, n.id DESC
           LIMIT 50`,
          [userId]
        ),
        db.query(
          `SELECT COUNT(*)::int AS unread_count
           FROM notifications
           WHERE user_id = $1 AND is_read = false`,
          [userId]
        ),
      ]);

      return res.json({
        data: listRes.rows.map(formatNotificationRow),
        meta: {
          unread_count: Number(countRes.rows[0]?.unread_count ?? 0),
        },
      });
    } catch (err) {
      return next(err);
    }
  });

  router.get('/unread-count', requireAuth, async (req, res, next) => {
    try {
      const countRes = await db.query(
        `SELECT COUNT(*)::int AS unread_count
         FROM notifications
         WHERE user_id = $1 AND is_read = false`,
        [req.user.id]
      );
      return res.json({
        data: {
          unread_count: Number(countRes.rows[0]?.unread_count ?? 0),
        },
      });
    } catch (err) {
      return next(err);
    }
  });

  router.patch(
    '/:id/read',
    requireAuth,
    validate(notificationIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const result = await db.query(
          `UPDATE notifications
           SET is_read = true
           WHERE id = $1 AND user_id = $2
           RETURNING id, is_read`,
          [req.params.id, req.user.id]
        );
        if (result.rows.length === 0) {
          return next(Errors.notFound('Notifikasi tidak ditemukan.'));
        }
        return res.json({ data: result.rows[0] });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.post('/read-all', requireAuth, async (req, res, next) => {
    try {
      await db.query(
        `UPDATE notifications
         SET is_read = true
         WHERE user_id = $1 AND is_read = false`,
        [req.user.id]
      );
      return res.json({
        data: { unread_count: 0 },
      });
    } catch (err) {
      return next(err);
    }
  });

  return router;
}

module.exports = { createNotificationsRouter };
