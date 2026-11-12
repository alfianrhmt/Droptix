'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');

const STRICT_CATEGORY_SLUGS = new Set(['konser-festival', 'olahraga']);
const MAX_EVENTS_PER_DAY = 5;

const listEventsQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  category: z.string().trim().max(30).optional(),
});

const createEventSchema = z.object({
  category_id: z.coerce.number().int().positive('Kategori wajib dipilih.'),
  nama: z
    .string()
    .trim()
    .min(3, 'Nama event minimal 3 karakter.')
    .max(120, 'Nama event maksimal 120 karakter.'),
  poster_url: z.string().trim().max(500).nullable().optional(),
  venue_id: z.coerce.number().int().positive().nullable().optional(),
  tanggal: z.string().datetime({ offset: true }).nullable().optional(),
  force: z.boolean().optional().default(false),
});

const updateEventSchema = z.object({
  nama: z
    .string()
    .trim()
    .min(3, 'Nama event minimal 3 karakter.')
    .max(120, 'Nama event maksimal 120 karakter.')
    .optional(),
  poster_url: z.string().trim().max(500).nullable().optional(),
  venue_id: z.coerce.number().int().positive().nullable().optional(),
  tanggal: z.string().datetime({ offset: true }).nullable().optional(),
});

const eventIdParamSchema = z.object({
  id: z.coerce.number().int().positive('ID event tidak valid.'),
});

function normalizeEventName(nama) {
  return nama.trim().replace(/\s+/g, ' ').toLowerCase();
}

function formatEventRow(row) {
  return {
    id: row.id,
    nama: row.nama,
    poster_url: row.poster_url ?? null,
    category: {
      id: row.category_id,
      slug: row.category_slug,
      nama: row.category_nama,
      ikon: row.category_ikon,
    },
    venue: row.venue_id
      ? {
          id: row.venue_id,
          nama: row.venue_nama,
          kota: row.venue_kota,
          alamat: row.venue_alamat ?? null,
          lat: row.venue_lat ?? null,
          lng: row.venue_lng ?? null,
        }
      : null,
    tanggal: row.tanggal ?? null,
  };
}

function ensureFutureDate(tanggal) {
  if (!tanggal) return;
  const parsed = new Date(tanggal);
  if (Number.isNaN(parsed.getTime()) || parsed.getTime() <= Date.now()) {
    throw Errors.validation('Data tidak valid', [
      { field: 'tanggal', message: 'Tanggal event harus di masa depan.' },
    ]);
  }
}

async function fetchEventById(db, id) {
  const result = await db.query(
    `SELECT e.id, e.nama, e.poster_url, e.tanggal, e.created_by, e.hidden,
            c.id AS category_id, c.slug AS category_slug, c.nama AS category_nama, c.ikon AS category_ikon,
            v.id AS venue_id, v.nama AS venue_nama, v.kota AS venue_kota,
            v.alamat AS venue_alamat, v.lat AS venue_lat, v.lng AS venue_lng
     FROM events e
     JOIN categories c ON c.id = e.category_id
     LEFT JOIN venues v ON v.id = e.venue_id
     WHERE e.id = $1`,
    [id]
  );
  return result.rows[0] || null;
}

/**
 * Router master data & pembuatan event.
 */
function createEventsRouter(db, requireAuth) {
  const router = express.Router();

  router.get('/', validate(listEventsQuerySchema, 'query'), async (req, res, next) => {
    try {
      const { q, category } = req.query;
      const conditions = [
        'e.hidden = false',
        `(e.tanggal IS NULL OR e.tanggal > now() OR EXISTS (
          SELECT 1 FROM listings l
          WHERE l.event_id = e.id
            AND l.deleted_at IS NULL
            AND l.hidden = false
            AND l.jumlah_terjual < l.jumlah_total
            AND l.waktu_acara > now()
        ))`,
      ];
      const params = [];

      if (q) {
        const normalized = normalizeEventName(q);
        params.push(`%${normalized}%`);
        conditions.push(`e.nama_normal LIKE $${params.length}`);
      }
      if (category) {
        params.push(category);
        conditions.push(`c.slug = $${params.length}`);
      }

      const result = await db.query(
        `SELECT e.id, e.nama, e.poster_url, e.tanggal,
                c.id AS category_id, c.slug AS category_slug, c.nama AS category_nama, c.ikon AS category_ikon,
                v.id AS venue_id, v.nama AS venue_nama, v.kota AS venue_kota,
                v.alamat AS venue_alamat, v.lat AS venue_lat, v.lng AS venue_lng
         FROM events e
         JOIN categories c ON c.id = e.category_id
         LEFT JOIN venues v ON v.id = e.venue_id
         WHERE ${conditions.join(' AND ')}
         ORDER BY e.tanggal ASC NULLS LAST, e.id DESC
         LIMIT 10`,
        params
      );

      return res.json({ data: result.rows.map(formatEventRow) });
    } catch (err) {
      return next(err);
    }
  });

  router.post('/', requireAuth, validate(createEventSchema), async (req, res, next) => {
    try {
      const { category_id, nama, poster_url, venue_id, tanggal, force } = req.body;

      ensureFutureDate(tanggal);

      const catResult = await db.query(
        'SELECT id, slug, nama, ikon FROM categories WHERE id = $1',
        [category_id]
      );
      const category = catResult.rows[0];
      if (!category) {
        return next(
          Errors.validation('Data tidak valid', [
            { field: 'category_id', message: 'Kategori tidak ditemukan.' },
          ])
        );
      }

      if (STRICT_CATEGORY_SLUGS.has(category.slug)) {
        const details = [];
        if (!venue_id) {
          details.push({ field: 'venue_id', message: 'Venue wajib diisi untuk kategori ini.' });
        }
        if (!tanggal) {
          details.push({ field: 'tanggal', message: 'Tanggal wajib diisi untuk kategori ini.' });
        }
        if (details.length > 0) {
          return next(Errors.validation('Data tidak valid', details));
        }
      }

      if (venue_id) {
        const venueResult = await db.query('SELECT id FROM venues WHERE id = $1', [venue_id]);
        if (venueResult.rows.length === 0) {
          return next(
            Errors.validation('Data tidak valid', [
              { field: 'venue_id', message: 'Venue tidak ditemukan.' },
            ])
          );
        }
      }

      const dailyCountResult = await db.query(
        `SELECT COUNT(*)::int AS total
         FROM events
         WHERE created_by = $1
           AND created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta'`,
        [req.user.id]
      );
      if (Number(dailyCountResult.rows[0]?.total ?? 0) >= MAX_EVENTS_PER_DAY) {
        return next(
          Errors.rateLimited('Batas maksimal 5 event baru per hari telah tercapai.')
        );
      }

      const namaNormal = normalizeEventName(nama);
      if (!force) {
        const similarResult = await db.query(
          `SELECT id, nama, poster_url
           FROM events
           WHERE category_id = $1
             AND hidden = false
             AND similarity(nama_normal, $2) >= 0.5
           ORDER BY similarity(nama_normal, $2) DESC, id ASC
           LIMIT 5`,
          [category_id, namaNormal]
        );
        if (similarResult.rows.length > 0) {
          return next(Errors.similarEvent(similarResult.rows));
        }
      }

      const insertResult = await db.query(
        `INSERT INTO events (category_id, nama, nama_normal, poster_url, venue_id, tanggal, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id`,
        [
          category_id,
          nama.trim(),
          namaNormal,
          poster_url ?? null,
          venue_id ?? null,
          tanggal ?? null,
          req.user.id,
        ]
      );

      const created = await fetchEventById(db, insertResult.rows[0].id);
      return res.status(201).json({ data: formatEventRow(created) });
    } catch (err) {
      return next(err);
    }
  });

  router.put(
    '/:id',
    requireAuth,
    validate(eventIdParamSchema, 'params'),
    validate(updateEventSchema),
    async (req, res, next) => {
      try {
        const eventId = req.params.id;
        const existing = await fetchEventById(db, eventId);
        if (!existing || existing.hidden) {
          return next(Errors.notFound('Event tidak ditemukan.'));
        }
        if (existing.created_by !== req.user.id) {
          return next(Errors.forbidden('Hanya pembuat event yang dapat mengubah event ini.'));
        }

        const lockResult = await db.query(
          `SELECT 1 FROM listings
           WHERE event_id = $1
             AND seller_id <> $2
             AND deleted_at IS NULL
           LIMIT 1`,
          [eventId, req.user.id]
        );
        if (lockResult.rows.length > 0) {
          return next(Errors.eventLocked());
        }

        const nextNama = req.body.nama !== undefined ? req.body.nama.trim() : existing.nama;
        const nextPosterUrl =
          req.body.poster_url !== undefined ? req.body.poster_url : existing.poster_url;
        const nextVenueId =
          req.body.venue_id !== undefined ? req.body.venue_id : existing.venue_id;
        const nextTanggal =
          req.body.tanggal !== undefined ? req.body.tanggal : existing.tanggal;

        if (req.body.tanggal !== undefined && req.body.tanggal !== null) {
          ensureFutureDate(req.body.tanggal);
        }

        if (STRICT_CATEGORY_SLUGS.has(existing.category_slug)) {
          const details = [];
          if (!nextVenueId) {
            details.push({ field: 'venue_id', message: 'Venue wajib diisi untuk kategori ini.' });
          }
          if (!nextTanggal) {
            details.push({ field: 'tanggal', message: 'Tanggal wajib diisi untuk kategori ini.' });
          }
          if (details.length > 0) {
            return next(Errors.validation('Data tidak valid', details));
          }
        }

        if (req.body.venue_id) {
          const venueResult = await db.query('SELECT id FROM venues WHERE id = $1', [
            req.body.venue_id,
          ]);
          if (venueResult.rows.length === 0) {
            return next(
              Errors.validation('Data tidak valid', [
                { field: 'venue_id', message: 'Venue tidak ditemukan.' },
              ])
            );
          }
        }

        await db.query(
          `UPDATE events
           SET nama = $1, nama_normal = $2, poster_url = $3, venue_id = $4, tanggal = $5
           WHERE id = $6`,
          [
            nextNama,
            normalizeEventName(nextNama),
            nextPosterUrl ?? null,
            nextVenueId ?? null,
            nextTanggal ?? null,
            eventId,
          ]
        );

        const updated = await fetchEventById(db, eventId);
        return res.json({ data: formatEventRow(updated) });
      } catch (err) {
        return next(err);
      }
    }
  );

  return router;
}

module.exports = { createEventsRouter, normalizeEventName };

