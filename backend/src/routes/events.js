'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');
const { formatListingCard } = require('./listings');

const STRICT_VENUE_CATEGORY_SLUGS = new Set(['konser-festival', 'olahraga', 'wisata']);
const STRICT_TANGGAL_CATEGORY_SLUGS = new Set(['konser-festival', 'olahraga']);
const MAX_EVENTS_PER_DAY = 5;

const getTrendingQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});

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
  tanggal_opsi: z.array(z.string().trim()).nullable().optional(),
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
  tanggal_opsi: z.array(z.string().trim()).nullable().optional(),
});

const eventIdParamSchema = z.object({
  id: z.coerce.number().int().positive('ID event tidak valid.'),
});

function normalizeEventName(nama) {
  return nama.trim().replace(/\s+/g, ' ').toLowerCase();
}

function formatEventRow(row) {
  let tanggalOpsi = [];
  if (Array.isArray(row.tanggal_opsi) && row.tanggal_opsi.length > 0) {
    tanggalOpsi = row.tanggal_opsi
      .map((d) => (d instanceof Date ? d.toISOString().split('T')[0] : String(d).split('T')[0]))
      .filter(Boolean);
  } else if (row.tanggal) {
    const d = row.tanggal instanceof Date ? row.tanggal : new Date(row.tanggal);
    if (!Number.isNaN(d.getTime())) {
      tanggalOpsi = [d.toISOString().split('T')[0]];
    }
  }

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
    tanggal_opsi: tanggalOpsi,
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
    `SELECT e.id, e.nama, e.poster_url, e.tanggal, e.tanggal_opsi, e.created_by, e.hidden,
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

  router.get('/trending', validate(getTrendingQuerySchema, 'query'), async (req, res, next) => {
    try {
      const { lat, lng } = req.query;
      const hasLat = lat !== undefined;
      const hasLng = lng !== undefined;

      if ((hasLat && !hasLng) || (!hasLat && hasLng)) {
        return next(
          Errors.validation('Koordinat lat dan lng harus diberikan berpasangan.', [
            { field: 'lat', message: 'lat dan lng harus berpasangan.' },
          ])
        );
      }

      const banners = [];

      // 1. Kategori acara (Konser & Festival, Olahraga, Hiburan Lain) -> Banner "event"
      // skor_event = active_listings_count + 0.5 * new_convs_7d
      const eventScoresSql = `
        WITH event_scores AS (
          SELECT e.id, e.category_id, e.nama, e.poster_url,
                 c.slug AS category_slug, c.urutan AS category_urutan,
                 COUNT(DISTINCT l.id)::int AS active_listings_count,
                 COUNT(DISTINCT cv.id)::int AS convs_7d_count,
                 (COUNT(DISTINCT l.id)::numeric + 0.5 * COUNT(DISTINCT cv.id)::numeric) AS skor_event
          FROM events e
          JOIN categories c ON c.id = e.category_id
          JOIN listings l ON l.event_id = e.id
          JOIN users u ON u.id = l.seller_id
          LEFT JOIN conversations cv ON cv.listing_id = l.id AND cv.created_at >= now() - interval '7 days'
          WHERE e.hidden = false
            AND c.slug IN ('konser-festival', 'olahraga', 'hiburan-lain')
            AND l.deleted_at IS NULL
            AND l.hidden = false
            AND l.waktu_acara > now()
            AND (l.jumlah_total - l.jumlah_terjual) > 0
            AND u.banned_at IS NULL
          GROUP BY e.id, e.category_id, e.nama, e.poster_url, c.slug, c.urutan
          HAVING COUNT(DISTINCT l.id) > 0
        ),
        ranked_events AS (
          SELECT *,
                 ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY skor_event DESC, id ASC) AS rn
          FROM event_scores
        )
        SELECT * FROM ranked_events WHERE rn = 1
      `;
      const eventScoresRes = await db.query(eventScoresSql);
      for (const row of eventScoresRes.rows) {
        banners.push({
          type: 'event',
          category_slug: row.category_slug,
          category_urutan: row.category_urutan,
          event: {
            id: row.id,
            nama: row.nama,
            poster_url: row.poster_url ?? null,
          },
        });
      }

      // 2. Kategori lokasi (Bioskop, Wisata) -> Banner "nearest"
      // Hanya jika koordinat pengguna diberikan
      if (hasLat && hasLng) {
        const nearestSql = `
          WITH ranked_listings AS (
            SELECT l.*,
                   e.nama AS event_nama, e.poster_url AS event_poster_url,
                   c.id AS category_id, c.slug AS category_slug, c.nama AS category_nama, c.urutan AS category_urutan,
                   v.nama AS venue_nama, v.kota AS venue_kota,
                   (SELECT count(*)::int FROM conversations cv WHERE cv.listing_id = l.id) AS tertarik,
                   false AS is_favorite,
                   (6371 * 2 * asin(sqrt(power(sin(radians(l.ref_lat - $1) / 2), 2) + cos(radians($1)) * cos(radians(l.ref_lat)) * power(sin(radians(l.ref_lng - $2) / 2), 2)))) AS jarak_calc,
                   ROW_NUMBER() OVER (
                     PARTITION BY c.id
                     ORDER BY (6371 * 2 * asin(sqrt(power(sin(radians(l.ref_lat - $1) / 2), 2) + cos(radians($1)) * cos(radians(l.ref_lat)) * power(sin(radians(l.ref_lng - $2) / 2), 2)))) ASC,
                              l.waktu_acara ASC,
                              l.id DESC
                   ) AS rn
            FROM listings l
            JOIN events e ON e.id = l.event_id
            JOIN categories c ON c.id = e.category_id
            LEFT JOIN venues v ON v.id = l.venue_id
            JOIN users u ON u.id = l.seller_id
            WHERE c.slug IN ('bioskop', 'wisata')
              AND e.hidden = false
              AND l.deleted_at IS NULL
              AND l.hidden = false
              AND l.waktu_acara > now()
              AND (l.jumlah_total - l.jumlah_terjual) > 0
              AND u.banned_at IS NULL
              AND l.ref_lat IS NOT NULL
              AND l.ref_lng IS NOT NULL
          )
          SELECT * FROM ranked_listings WHERE rn = 1
        `;
        const nearestRes = await db.query(nearestSql, [lat, lng]);
        for (const row of nearestRes.rows) {
          banners.push({
            type: 'nearest',
            category_slug: row.category_slug,
            category_urutan: row.category_urutan,
            listing: formatListingCard(row, lat, lng),
          });
        }
      }

      // 3. Urutkan sesuai categories.urutan, maksimal 5 banner
      banners.sort((a, b) => a.category_urutan - b.category_urutan);
      const data = banners.slice(0, 5).map(({ category_urutan, ...banner }) => banner);

      return res.json({ data });
    } catch (err) {
      return next(err);
    }
  });

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
        `SELECT e.id, e.nama, e.poster_url, e.tanggal, e.tanggal_opsi,
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
      const { category_id, nama, poster_url, venue_id, tanggal, tanggal_opsi, force } = req.body;

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

      const details = [];
      if (STRICT_VENUE_CATEGORY_SLUGS.has(category.slug) && !venue_id) {
        details.push({ field: 'venue_id', message: 'Venue wajib diisi untuk kategori ini.' });
      }

      let resolvedTanggalOpsi = null;
      let resolvedTanggal = tanggal ? new Date(tanggal) : null;

      if (Array.isArray(tanggal_opsi) && tanggal_opsi.length > 0) {
        resolvedTanggalOpsi = tanggal_opsi.map((d) => String(d).trim()).filter(Boolean);
        if (!resolvedTanggal && resolvedTanggalOpsi.length > 0) {
          resolvedTanggal = new Date(`${resolvedTanggalOpsi[0]}T00:00:00Z`);
        }
      } else if (resolvedTanggal) {
        resolvedTanggalOpsi = [resolvedTanggal.toISOString().split('T')[0]];
      }

      if (STRICT_TANGGAL_CATEGORY_SLUGS.has(category.slug) && !resolvedTanggal) {
        details.push({ field: 'tanggal', message: 'Tanggal wajib diisi untuk kategori ini.' });
      }

      if (details.length > 0) {
        return next(Errors.validation('Data tidak valid', details));
      }

      if (resolvedTanggal) {
        ensureFutureDate(resolvedTanggal.toISOString());
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
        `INSERT INTO events (category_id, nama, nama_normal, poster_url, venue_id, tanggal, tanggal_opsi, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING id`,
        [
          category_id,
          nama.trim(),
          namaNormal,
          poster_url ?? null,
          venue_id ?? null,
          resolvedTanggal ? resolvedTanggal.toISOString() : null,
          resolvedTanggalOpsi,
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
        let nextTanggalOpsi =
          req.body.tanggal_opsi !== undefined ? req.body.tanggal_opsi : existing.tanggal_opsi;
        let nextTanggal =
          req.body.tanggal !== undefined ? req.body.tanggal : existing.tanggal;

        if (Array.isArray(nextTanggalOpsi) && nextTanggalOpsi.length > 0) {
          nextTanggalOpsi = nextTanggalOpsi.map((d) => String(d).trim()).filter(Boolean);
          if (!nextTanggal && nextTanggalOpsi.length > 0) {
            nextTanggal = `${nextTanggalOpsi[0]}T00:00:00Z`;
          }
        }

        if (nextTanggal) {
          ensureFutureDate(nextTanggal);
        }

        const details = [];
        if (STRICT_VENUE_CATEGORY_SLUGS.has(existing.category_slug) && !nextVenueId) {
          details.push({ field: 'venue_id', message: 'Venue wajib diisi untuk kategori ini.' });
        }
        if (STRICT_TANGGAL_CATEGORY_SLUGS.has(existing.category_slug) && !nextTanggal) {
          details.push({ field: 'tanggal', message: 'Tanggal wajib diisi untuk kategori ini.' });
        }
        if (details.length > 0) {
          return next(Errors.validation('Data tidak valid', details));
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
           SET nama = $1, nama_normal = $2, poster_url = $3, venue_id = $4, tanggal = $5, tanggal_opsi = $6
           WHERE id = $7`,
          [
            nextNama,
            normalizeEventName(nextNama),
            nextPosterUrl ?? null,
            nextVenueId ?? null,
            nextTanggal ?? null,
            nextTanggalOpsi,
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

