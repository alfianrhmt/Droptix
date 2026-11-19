'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');
const { normalizeWaNumber } = require('../utils/phone');
const { formatListingCard } = require('./listings');
const { countUnreadChats } = require('./conversations');

const getMyListingsQuerySchema = z.object({
  status: z.enum(['tersedia', 'terjual', 'kedaluwarsa']).optional(),
  page: z.coerce.number().int().min(1).optional().default(1),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

const getMyFavoritesQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  page: z.coerce.number().int().min(1).optional().default(1),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

const updateMeSchema = z.object({
  nama: z
    .string()
    .trim()
    .min(2, 'Nama minimal 2 karakter.')
    .max(80, 'Nama maksimal 80 karakter.')
    .optional(),
  no_wa: z.string().trim().optional().nullable(),
  kota: z
    .string()
    .trim()
    .min(2, 'Nama kota minimal 2 karakter.')
    .max(60, 'Nama kota maksimal 60 karakter.')
    .optional()
    .nullable(),
  foto_url: z.string().trim().optional().nullable(),
});

const updatePasswordSchema = z.object({
  password_lama: z
    .string({ required_error: 'Password lama wajib diisi.' })
    .min(1, 'Password lama wajib diisi.'),
  password_baru: z
    .string({ required_error: 'Password baru wajib diisi.' })
    .min(8, 'Password baru minimal 8 karakter.'),
});

function createMeRouter(db, requireAuth) {
  const router = express.Router();

  router.get('/', requireAuth, (req, res) => {
    res.json({ data: req.user });
  });

  router.get('/unread', requireAuth, async (req, res, next) => {
    try {
      const chats = await countUnreadChats(db, req.user.id);
      return res.json({
        data: {
          chats,
        },
      });
    } catch (err) {
      return next(err);
    }
  });

  router.get('/blocks', requireAuth, async (req, res, next) => {
    try {
      const sql = `
        SELECT u.id, u.nama
        FROM blocks b
        JOIN users u ON u.id = b.blocked_id
        WHERE b.blocker_id = $1
        ORDER BY b.created_at DESC
      `;
      const { rows } = await db.query(sql, [req.user.id]);
      return res.json({
        data: rows.map((r) => ({
          id: Number(r.id),
          nama: r.nama,
        })),
      });
    } catch (err) {
      return next(err);
    }
  });

  router.get(
    '/listings',
    requireAuth,
    validate(getMyListingsQuerySchema, 'query'),
    async (req, res, next) => {
      try {
        const { status, page, limit } = req.query;
        const offset = (page - 1) * limit;

        let statusFilter = '';
        if (status === 'tersedia') {
          statusFilter =
            'AND l.waktu_acara > now() AND (l.jumlah_total - l.jumlah_terjual) > 0';
        } else if (status === 'terjual') {
          statusFilter =
            'AND l.waktu_acara > now() AND (l.jumlah_total - l.jumlah_terjual) <= 0';
        } else if (status === 'kedaluwarsa') {
          statusFilter = 'AND l.waktu_acara <= now()';
        }

        const countRes = await db.query(
          `SELECT count(*)::int AS total
           FROM listings l
           WHERE l.seller_id = $1
             AND l.deleted_at IS NULL
             AND l.hidden = false
             ${statusFilter}`,
          [req.user.id]
        );
        const total = countRes.rows[0]?.total || 0;

        const { rows } = await db.query(
          `SELECT l.*,
                  e.nama AS event_nama, e.poster_url AS event_poster_url,
                  c.id AS category_id, c.slug AS category_slug, c.nama AS category_nama,
                  v.nama AS venue_nama, v.kota AS venue_kota,
                  (SELECT count(*)::int FROM conversations cv WHERE cv.listing_id = l.id) AS tertarik
           FROM listings l
           JOIN events e ON e.id = l.event_id
           JOIN categories c ON c.id = e.category_id
           LEFT JOIN venues v ON v.id = l.venue_id
           WHERE l.seller_id = $1
             AND l.deleted_at IS NULL
             AND l.hidden = false
             ${statusFilter}
           ORDER BY l.created_at DESC
           LIMIT $2 OFFSET $3`,
          [req.user.id, limit, offset]
        );

        const data = rows.map((r) => formatListingCard(r));
        return res.json({
          data,
          meta: {
            page,
            limit,
            total,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.get(
    '/favorites',
    requireAuth,
    validate(getMyFavoritesQuerySchema, 'query'),
    async (req, res, next) => {
      try {
        const { lat, lng, page, limit } = req.query;
        const offset = (page - 1) * limit;

        const countRes = await db.query(
          `SELECT count(*)::int AS total
           FROM favorites f
           JOIN listings l ON l.id = f.listing_id
           JOIN users u ON u.id = l.seller_id
           WHERE f.user_id = $1
             AND l.deleted_at IS NULL
             AND l.hidden = false
             AND u.banned_at IS NULL`,
          [req.user.id]
        );
        const total = countRes.rows[0]?.total || 0;

        const { rows } = await db.query(
          `SELECT l.*,
                  e.nama AS event_nama, e.poster_url AS event_poster_url,
                  c.id AS category_id, c.slug AS category_slug, c.nama AS category_nama,
                  v.nama AS venue_nama, v.kota AS venue_kota,
                  (SELECT count(*)::int FROM conversations cv WHERE cv.listing_id = l.id) AS tertarik,
                  true AS is_favorite
           FROM favorites f
           JOIN listings l ON l.id = f.listing_id
           JOIN events e ON e.id = l.event_id
           JOIN categories c ON c.id = e.category_id
           JOIN users u ON u.id = l.seller_id
           LEFT JOIN venues v ON v.id = l.venue_id
           WHERE f.user_id = $1
             AND l.deleted_at IS NULL
             AND l.hidden = false
             AND u.banned_at IS NULL
           ORDER BY f.created_at DESC, l.id DESC
           LIMIT $2 OFFSET $3`,
          [req.user.id, limit, offset]
        );

        const data = rows.map((r) =>
          formatListingCard(
            r,
            lat !== undefined ? lat : null,
            lng !== undefined ? lng : null
          )
        );

        return res.json({
          data,
          meta: {
            page,
            limit,
            total,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.put(
    '/',
    requireAuth,
    validate(updateMeSchema),
    async (req, res, next) => {
      try {
        const { nama, no_wa, kota, foto_url } = req.body;

        let nextWa = req.user.no_wa;
        if (no_wa !== undefined) {
          if (no_wa === null || no_wa === '') {
            nextWa = null;
          } else {
            const normalized = normalizeWaNumber(no_wa);
            if (!normalized) {
              return next(
                Errors.validation('Data tidak valid', [
                  {
                    field: 'no_wa',
                    message:
                      'Nomor WhatsApp tidak valid (contoh: 081234567890).',
                  },
                ])
              );
            }
            nextWa = normalized;
          }
        }

        const nextNama = nama !== undefined ? nama : req.user.nama;
        const nextKota = kota !== undefined ? kota || null : req.user.kota;
        const nextFotoUrl =
          foto_url !== undefined
            ? foto_url === null || foto_url === ''
              ? null
              : foto_url
            : req.user.foto_url;

        const { rows } = await db.query(
          `UPDATE users
           SET nama = $1, no_wa = $2, kota = $3, foto_url = $4
           WHERE id = $5
           RETURNING id, nama, email, no_wa, kota, foto_url, created_at`,
          [nextNama, nextWa, nextKota, nextFotoUrl, req.user.id]
        );

        return res.json({ data: rows[0] });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.put(
    '/password',
    requireAuth,
    validate(updatePasswordSchema),
    async (req, res, next) => {
      try {
        const { password_lama, password_baru } = req.body;
        const { rows } = await db.query(
          'SELECT password_hash FROM users WHERE id = $1 LIMIT 1',
          [req.user.id]
        );

        if (rows.length === 0) {
          return next(Errors.unauthorized());
        }

        const match = await bcrypt.compare(
          password_lama,
          rows[0].password_hash
        );
        if (!match) {
          return next(
            Errors.validation('Password lama salah.', [
              { field: 'password_lama', message: 'Password lama tidak sesuai.' },
            ])
          );
        }

        const newHash = await bcrypt.hash(password_baru, 10);
        await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
          newHash,
          req.user.id,
        ]);

        return res.json({ data: { ok: true } });
      } catch (err) {
        return next(err);
      }
    }
  );

  return router;
}

module.exports = { createMeRouter };

