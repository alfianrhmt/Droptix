'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');
const {
  buildRelevanceSqlOrder,
  computeRelevanceScore,
  RELEVANCE_WEIGHTS,
} = require('../config/relevance');
const { chatMessageLimiter } = require('../middleware/rateLimit');
const { computeListingStatus } = require('../utils/status');
const {
  formatConversation,
  formatMessage,
  fetchConversationWithDetails,
  checkBlockBetween,
  countUnreadChats,
  postMessageBodySchema,
} = require('./conversations');
const { emitMessageNew } = require('../realtime');

const listingIdParamSchema = z.object({
  id: z.coerce.number().int().positive('ID listing tidak valid.'),
});

const getListingQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});

const getListingsQuerySchema = z.object({
  q: z.string().trim().max(100).optional(),
  category: z.string().trim().max(50).optional(),
  jenis: z.enum(['limited', 'last_minute']).optional(),
  tipe: z.enum(['digital', 'fisik']).optional(),
  kota: z.string().trim().max(60).optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  max_km: z.coerce.number().int().positive().optional(),
  min_harga: z.coerce.number().int().min(0).optional(),
  max_harga: z.coerce.number().int().min(0).optional(),
  tanggal: z.string().trim().optional(),
  dalam_jam: z.coerce.number().int().positive().optional(),
  tersedia: z
    .preprocess((val) => {
      if (val === undefined) return true;
      if (typeof val === 'string') return val !== 'false';
      return Boolean(val);
    }, z.boolean())
    .optional()
    .default(true),
  sort: z
    .enum(['relevan', 'terdekat', 'termurah', 'segera', 'terbaru'])
    .optional()
    .default('relevan'),
  page: z.coerce.number().int().min(1).optional().default(1),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

const photoPathSchema = z
  .string()
  .trim()
  .refine((p) => p.startsWith('/uploads/'), {
    message: 'Path foto harus berasal dari /uploads/.',
  });

const createListingSchema = z.object({
  event_id: z.coerce.number().int().positive('Event wajib dipilih.'),
  venue_id: z.coerce.number().int().positive().nullable().optional(),
  venue_teks: z.string().trim().max(120).nullable().optional(),
  kota: z.string().trim().max(60).nullable().optional(),
  waktu_acara: z.string().datetime({ offset: true }),
  jenis: z.enum(['limited', 'last_minute']),
  tipe: z.enum(['digital', 'fisik']),
  seksi: z.string().trim().max(60).nullable().optional(),
  no_kursi: z.string().trim().max(60).nullable().optional(),
  harga: z.coerce.number().int().positive('Harga harus lebih dari 0.'),
  harga_asli: z.coerce.number().int().positive().nullable().optional(),
  jumlah_total: z.coerce.number().int().min(1, 'Jumlah tiket minimal 1.'),
  satuan: z.boolean().optional().default(true),
  terikat_nama: z.enum(['ya', 'tidak', 'tidak_tahu']),
  serah_terima: z.array(z.string().trim()),
  lokasi_penjual_kota: z.string().trim().max(60).nullable().optional(),
  lokasi_penjual_lat: z.coerce.number().min(-90).max(90).nullable().optional(),
  lokasi_penjual_lng: z.coerce.number().min(-180).max(180).nullable().optional(),
  catatan: z.string().trim().max(2000).nullable().optional(),
  izinkan_wa: z.boolean().optional().default(false),
  photos: z
    .array(photoPathSchema)
    .min(1, 'Minimal 1 foto tiket wajib diunggah.')
    .max(3, 'Maksimal 3 foto tiket.'),
});

const updateListingSchema = z.object({
  event_id: z.coerce.number().int().positive().optional(),
  venue_id: z.coerce.number().int().positive().nullable().optional(),
  venue_teks: z.string().trim().max(120).nullable().optional(),
  kota: z.string().trim().max(60).nullable().optional(),
  waktu_acara: z.string().datetime({ offset: true }).optional(),
  jenis: z.enum(['limited', 'last_minute']).optional(),
  tipe: z.enum(['digital', 'fisik']).optional(),
  seksi: z.string().trim().max(60).nullable().optional(),
  no_kursi: z.string().trim().max(60).nullable().optional(),
  harga: z.coerce.number().int().positive().optional(),
  harga_asli: z.coerce.number().int().positive().nullable().optional(),
  jumlah_total: z.coerce.number().int().min(1).optional(),
  satuan: z.boolean().optional(),
  terikat_nama: z.enum(['ya', 'tidak', 'tidak_tahu']).optional(),
  serah_terima: z.array(z.string().trim()).optional(),
  lokasi_penjual_kota: z.string().trim().max(60).nullable().optional(),
  lokasi_penjual_lat: z.coerce.number().min(-90).max(90).nullable().optional(),
  lokasi_penjual_lng: z.coerce.number().min(-180).max(180).nullable().optional(),
  catatan: z.string().trim().max(2000).nullable().optional(),
  izinkan_wa: z.boolean().optional(),
  photos: z.array(photoPathSchema).min(1).max(3).optional(),
});

const patchStockSchema = z.object({
  jumlah_terjual: z.coerce.number().int().min(0, 'Jumlah terjual tidak boleh negatif.'),
});

function computeDiscountPercent(harga, hargaAsli) {
  if (!hargaAsli || harga >= hargaAsli) return null;
  return Math.round(((hargaAsli - harga) / hargaAsli) * 100);
}

function haversineKm(lat1, lng1, lat2, lng2) {
  if (
    lat1 == null ||
    lng1 == null ||
    lat2 == null ||
    lng2 == null
  ) {
    return null;
  }
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  const km = 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(km * 10) / 10;
}

function getWibDateRange(type, now = new Date()) {
  const wibOffsetMs = 7 * 60 * 60 * 1000;
  const wibNow = new Date(now.getTime() + wibOffsetMs);

  const curYear = wibNow.getUTCFullYear();
  const curMonth = wibNow.getUTCMonth();
  const curDate = wibNow.getUTCDate();
  const curDay = wibNow.getUTCDay(); // 0 = Minggu, 6 = Sabtu

  function createWibUtcDate(year, month, date, hours = 0, minutes = 0, seconds = 0, ms = 0) {
    return new Date(Date.UTC(year, month, date, hours, minutes, seconds, ms) - wibOffsetMs);
  }

  if (type === 'hari_ini') {
    const start = now;
    const end = createWibUtcDate(curYear, curMonth, curDate, 23, 59, 59, 999);
    return { start, end };
  }

  if (type === 'besok') {
    const start = createWibUtcDate(curYear, curMonth, curDate + 1, 0, 0, 0, 0);
    const end = createWibUtcDate(curYear, curMonth, curDate + 1, 23, 59, 59, 999);
    return { start, end };
  }

  if (type === 'akhir_pekan') {
    if (curDay === 6) {
      // Sabtu: sekarang sampai Minggu 23.59
      const start = now;
      const end = createWibUtcDate(curYear, curMonth, curDate + 1, 23, 59, 59, 999);
      return { start, end };
    }
    if (curDay === 0) {
      // Minggu: sekarang sampai Minggu 23.59
      const start = now;
      const end = createWibUtcDate(curYear, curMonth, curDate, 23, 59, 59, 999);
      return { start, end };
    }
    // Senin (1) .. Jumat (5): Sabtu 00.00 sampai Minggu 23.59
    const daysUntilSaturday = 6 - curDay;
    const start = createWibUtcDate(curYear, curMonth, curDate + daysUntilSaturday, 0, 0, 0, 0);
    const end = createWibUtcDate(curYear, curMonth, curDate + daysUntilSaturday + 1, 23, 59, 59, 999);
    return { start, end };
  }

  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(type);
  if (!match) {
    throw Errors.validation('Format tanggal tidak valid.', [
      { field: 'tanggal', message: 'Format tanggal harus hari_ini, besok, akhir_pekan, atau YYYY-MM-DD.' },
    ]);
  }

  const y = parseInt(match[1], 10);
  const m = parseInt(match[2], 10) - 1;
  const d = parseInt(match[3], 10);

  const testDate = new Date(Date.UTC(y, m, d));
  if (
    testDate.getUTCFullYear() !== y ||
    testDate.getUTCMonth() !== m ||
    testDate.getUTCDate() !== d
  ) {
    throw Errors.validation('Tanggal tidak valid.', [
      { field: 'tanggal', message: 'Tanggal kalender tidak valid.' },
    ]);
  }

  const start = createWibUtcDate(y, m, d, 0, 0, 0, 0);
  const end = createWibUtcDate(y, m, d, 23, 59, 59, 999);
  return { start, end };
}

function computeRefCoordinates({ tipe, lokasiPenjualLat, lokasiPenjualLng, venue }) {
  if (tipe === 'fisik') {
    if (lokasiPenjualLat != null && lokasiPenjualLng != null) {
      return { refLat: lokasiPenjualLat, refLng: lokasiPenjualLng };
    }
    return { refLat: null, refLng: null };
  }
  if (venue && venue.lat != null && venue.lng != null) {
    return { refLat: venue.lat, refLng: venue.lng };
  }
  return { refLat: null, refLng: null };
}

function formatListingCard(row, userLat = null, userLng = null) {
  const tersedia = Math.max(0, row.jumlah_total - row.jumlah_terjual);
  return {
    id: row.id,
    event: {
      id: row.event_id,
      nama: row.event_nama,
      poster_url: row.event_poster_url ?? null,
      category: {
        id: row.category_id,
        slug: row.category_slug,
        nama: row.category_nama,
      },
    },
    venue_nama: row.venue_id ? row.venue_nama : row.venue_teks,
    kota: row.kota,
    waktu_acara: row.waktu_acara,
    jenis: row.jenis,
    tipe: row.tipe,
    seksi: row.seksi ?? null,
    harga: row.harga,
    harga_asli: row.harga_asli ?? null,
    diskon_persen: computeDiscountPercent(row.harga, row.harga_asli),
    jumlah_total: row.jumlah_total,
    jumlah_tersedia: tersedia,
    jumlah_terjual: row.jumlah_terjual,
    tertarik: Number(row.tertarik ?? 0),
    status: computeListingStatus(row),
    jarak_km: haversineKm(userLat, userLng, row.ref_lat, row.ref_lng),
    diperbarui: row.updated_at,
    is_favorite: Boolean(row.is_favorite),
    confirmed_at: row.confirmed_at ?? null,
    created_at: row.created_at,
  };
}

function formatListingDetail(row, photos, userLat = null, userLng = null) {
  const tersedia = Math.max(0, row.jumlah_total - row.jumlah_terjual);
  return {
    id: row.id,
    event: {
      id: row.event_id,
      nama: row.event_nama,
      poster_url: row.event_poster_url ?? null,
      category: {
        id: row.category_id,
        slug: row.category_slug,
        nama: row.category_nama,
      },
    },
    venue_nama: row.venue_id ? row.venue_nama : row.venue_teks,
    kota: row.kota,
    waktu_acara: row.waktu_acara,
    jenis: row.jenis,
    tipe: row.tipe,
    seksi: row.seksi ?? null,
    harga: row.harga,
    harga_asli: row.harga_asli ?? null,
    diskon_persen: computeDiscountPercent(row.harga, row.harga_asli),
    jumlah_tersedia: tersedia,
    jumlah_terjual: row.jumlah_terjual,
    tertarik: Number(row.tertarik ?? 0),
    status: computeListingStatus(row),
    jarak_km: haversineKm(userLat, userLng, row.ref_lat, row.ref_lng),
    diperbarui: row.updated_at,
    is_favorite: Boolean(row.is_favorite),
    no_kursi: row.no_kursi ?? null,
    izinkan_wa: Boolean(row.izinkan_wa),
    satuan: Boolean(row.satuan),
    terikat_nama: row.terikat_nama,
    serah_terima: row.serah_terima || [],
    lokasi_penjual_kota: row.lokasi_penjual_kota ?? null,
    catatan: row.catatan ?? null,
    photos: photos.map((p) => ({ id: p.id, url: p.url })),
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
    seller: {
      id: row.seller_id,
      nama: row.seller_nama,
      username: row.seller_username || null,
      bergabung: row.seller_created_at,
    },
    confirmed_at: row.confirmed_at,
    created_at: row.created_at,
  };
}

function validateHandoverAndLocation({
  tipe,
  serahTerima,
  lokasiPenjualKota,
  venueId,
  venueTeks,
  kota,
}) {
  const details = [];

  if (!venueId && (!venueTeks || venueTeks.trim().length === 0)) {
    details.push({
      field: 'venue_id',
      message: 'Pilih venue atau isi nama venue secara manual.',
    });
  }
  if (!venueId && (!kota || kota.trim().length === 0)) {
    details.push({
      field: 'kota',
      message: 'Kota wajib diisi jika mengisi venue manual.',
    });
  }

  if (tipe === 'digital') {
    if (
      !Array.isArray(serahTerima) ||
      serahTerima.length !== 1 ||
      serahTerima[0] !== 'transfer_eticket'
    ) {
      details.push({
        field: 'serah_terima',
        message: 'Tiket digital hanya mendukung serah terima transfer_eticket.',
      });
    }
  } else if (tipe === 'fisik') {
    const allowed = new Set(['cod', 'ekspedisi']);
    const unique = [...new Set(serahTerima || [])];
    if (unique.length === 0 || unique.some((m) => !allowed.has(m))) {
      details.push({
        field: 'serah_terima',
        message: 'Tiket fisik wajib memilih cod dan/atau ekspedisi.',
      });
    }
    if (!lokasiPenjualKota || lokasiPenjualKota.trim().length === 0) {
      details.push({
        field: 'lokasi_penjual_kota',
        message: 'Kota penjual wajib diisi untuk tiket fisik.',
      });
    }
  }

  if (details.length > 0) {
    throw Errors.validation('Data tidak valid', details);
  }
}

async function fetchListingDetail(db, listingId, currentUserId = null, userLat = null, userLng = null) {
  const { rows } = await db.query(
    `SELECT l.*,
            e.nama AS event_nama, e.poster_url AS event_poster_url,
            c.id AS category_id, c.slug AS category_slug, c.nama AS category_nama,
            v.nama AS venue_nama, v.kota AS venue_kota, v.alamat AS venue_alamat,
            v.lat AS venue_lat, v.lng AS venue_lng,
            u.nama AS seller_nama, u.username AS seller_username, u.created_at AS seller_created_at,
            (SELECT count(*)::int FROM conversations cv WHERE cv.listing_id = l.id) AS tertarik,
            CASE WHEN $2::int IS NOT NULL THEN EXISTS (
              SELECT 1 FROM favorites f WHERE f.user_id = $2 AND f.listing_id = l.id
            ) ELSE false END AS is_favorite
     FROM listings l
     JOIN events e ON e.id = l.event_id
     JOIN categories c ON c.id = e.category_id
     LEFT JOIN venues v ON v.id = l.venue_id
     JOIN users u ON u.id = l.seller_id
     WHERE l.id = $1
     LIMIT 1`,
    [listingId, currentUserId]
  );

  const row = rows[0];
  if (!row) return null;

  const photoResult = await db.query(
    'SELECT id, url FROM listing_photos WHERE listing_id = $1 ORDER BY urutan ASC, id ASC',
    [listingId]
  );

  return {
    raw: row,
    detail: formatListingDetail(row, photoResult.rows, userLat, userLng),
  };
}

/**
 * Router pembuatan, pembacaan, dan pengelolaan listing tiket.
 */
function createListingsRouter(
  db,
  requireAuth,
  optionalAuth,
  useRateLimit = true
) {
  const router = express.Router();
  const msgLimiter = useRateLimit
    ? chatMessageLimiter
    : (_req, _res, next) => next();

  router.get(
    '/',
    optionalAuth,
    validate(getListingsQuerySchema, 'query'),
    async (req, res, next) => {
      try {
        const {
          q,
          category,
          jenis,
          tipe,
          kota,
          lat,
          lng,
          max_km,
          min_harga,
          max_harga,
          tanggal,
          dalam_jam,
          tersedia,
          sort,
          page,
          limit,
        } = req.query;

        // Validasi koordinat berpasangan
        const hasLat = lat !== undefined;
        const hasLng = lng !== undefined;
        if ((hasLat && !hasLng) || (!hasLat && hasLng)) {
          return next(
            Errors.validation('Koordinat lat dan lng harus diberikan berpasangan.', [
              { field: 'lat', message: 'lat dan lng harus berpasangan.' },
            ])
          );
        }

        // Urutan terdekat membutuhkan koordinat
        if (sort === 'terdekat' && (!hasLat || !hasLng)) {
          return next(
            Errors.validation('Urutan terdekat membutuhkan koordinat lat dan lng.', [
              { field: 'sort', message: 'Urutan terdekat membutuhkan koordinat lat dan lng.' },
            ])
          );
        }

        // Filter max_km membutuhkan koordinat
        if (max_km !== undefined && (!hasLat || !hasLng)) {
          return next(
            Errors.validation('Filter jarak maksimum (max_km) membutuhkan koordinat lat dan lng.', [
              { field: 'max_km', message: 'Filter jarak maksimum membutuhkan koordinat lat dan lng.' },
            ])
          );
        }

        // Rentang harga
        if (
          min_harga !== undefined &&
          max_harga !== undefined &&
          min_harga > max_harga
        ) {
          return next(
            Errors.validation('min_harga tidak boleh lebih besar dari max_harga.', [
              { field: 'min_harga', message: 'min_harga tidak boleh lebih besar dari max_harga.' },
            ])
          );
        }

        let dateRange = null;
        if (tanggal) {
          dateRange = getWibDateRange(tanggal);
        }

        const conditions = [
          'l.deleted_at IS NULL',
          'l.hidden = false',
          'l.waktu_acara > now()',
          'u.banned_at IS NULL',
          'e.hidden = false',
        ];
        const params = [];

        if (tersedia) {
          conditions.push('(l.jumlah_total - l.jumlah_terjual) > 0');
        }

        if (q) {
          params.push(`%${q}%`);
          const p = params.length;
          conditions.push(
            `(e.nama ILIKE $${p} OR v.nama ILIKE $${p} OR l.venue_teks ILIKE $${p} OR l.kota ILIKE $${p})`
          );
        }

        if (category) {
          params.push(category);
          conditions.push(`c.slug = $${params.length}`);
        }

        if (jenis) {
          params.push(jenis);
          conditions.push(`l.jenis = $${params.length}`);
        }

        if (tipe) {
          params.push(tipe);
          conditions.push(`l.tipe = $${params.length}`);
        }

        if (kota) {
          params.push(kota);
          conditions.push(`l.kota ILIKE $${params.length}`);
        }

        if (min_harga !== undefined) {
          params.push(min_harga);
          conditions.push(`l.harga >= $${params.length}`);
        }

        if (max_harga !== undefined) {
          params.push(max_harga);
          conditions.push(`l.harga <= $${params.length}`);
        }

        if (dalam_jam !== undefined) {
          const deadline = new Date(Date.now() + dalam_jam * 3600 * 1000).toISOString();
          params.push(deadline);
          conditions.push(`l.waktu_acara <= $${params.length}`);
        }

        if (dateRange) {
          params.push(dateRange.start.toISOString());
          const pStart = params.length;
          params.push(dateRange.end.toISOString());
          const pEnd = params.length;
          conditions.push(`(l.waktu_acara >= $${pStart} AND l.waktu_acara <= $${pEnd})`);
        }

        if (max_km !== undefined) {
          params.push(lat);
          const pLat = params.length;
          params.push(lng);
          const pLng = params.length;
          params.push(max_km);
          const pMax = params.length;
          conditions.push(
            `l.ref_lat IS NOT NULL AND l.ref_lng IS NOT NULL AND (6371 * 2 * asin(sqrt(power(sin(radians(l.ref_lat - $${pLat}) / 2), 2) + cos(radians($${pLat})) * cos(radians(l.ref_lat)) * power(sin(radians(l.ref_lng - $${pLng}) / 2), 2)))) <= $${pMax}`
          );
        }

        const whereSql = conditions.join(' AND ');

        const countSql = `SELECT count(*)::int AS total
          FROM listings l
          JOIN events e ON e.id = l.event_id
          JOIN categories c ON c.id = e.category_id
          LEFT JOIN venues v ON v.id = l.venue_id
          JOIN users u ON u.id = l.seller_id
          WHERE ${whereSql}`;

        const countRes = await db.query(countSql, [...params]);
        const total = countRes.rows[0]?.total ?? 0;

        let orderSql = '';
        const dataParams = [...params];

        if (sort === 'terdekat') {
          dataParams.push(lat);
          const pLat = dataParams.length;
          dataParams.push(lng);
          const pLng = dataParams.length;
          orderSql = `ORDER BY (CASE WHEN l.ref_lat IS NOT NULL AND l.ref_lng IS NOT NULL THEN (6371 * 2 * asin(sqrt(power(sin(radians(l.ref_lat - $${pLat}) / 2), 2) + cos(radians($${pLat})) * cos(radians(l.ref_lat)) * power(sin(radians(l.ref_lng - $${pLng}) / 2), 2)))) ELSE 999999 END) ASC, l.waktu_acara ASC, l.id DESC`;
        } else if (sort === 'termurah') {
          orderSql = 'ORDER BY l.harga ASC, l.waktu_acara ASC, l.id DESC';
        } else if (sort === 'segera') {
          orderSql = 'ORDER BY l.waktu_acara ASC, l.id DESC';
        } else if (sort === 'terbaru') {
          orderSql = 'ORDER BY l.created_at DESC, l.id DESC';
        } else {
          // BR-5 skor relevansi (default / sort=relevan)
          if (hasLat && hasLng) {
            dataParams.push(lat);
            const pLat = dataParams.length;
            dataParams.push(lng);
            const pLng = dataParams.length;
            orderSql = buildRelevanceSqlOrder({
              userLatParamIndex: pLat,
              userLngParamIndex: pLng,
            });
          } else {
            orderSql = buildRelevanceSqlOrder();
          }
        }

        const currentUserId = req.user ? req.user.id : null;
        dataParams.push(currentUserId);
        const pUid = dataParams.length;

        const offset = (page - 1) * limit;
        dataParams.push(limit);
        const pLimit = dataParams.length;
        dataParams.push(offset);
        const pOffset = dataParams.length;

        const dataSql = `SELECT l.*,
                e.nama AS event_nama, e.poster_url AS event_poster_url,
                c.id AS category_id, c.slug AS category_slug, c.nama AS category_nama,
                v.nama AS venue_nama, v.kota AS venue_kota,
                (SELECT count(*)::int FROM conversations cv WHERE cv.listing_id = l.id) AS tertarik,
                CASE WHEN $${pUid}::int IS NOT NULL THEN EXISTS (
                  SELECT 1 FROM favorites f WHERE f.user_id = $${pUid} AND f.listing_id = l.id
                ) ELSE false END AS is_favorite
         FROM listings l
         JOIN events e ON e.id = l.event_id
         JOIN categories c ON c.id = e.category_id
         LEFT JOIN venues v ON v.id = l.venue_id
         JOIN users u ON u.id = l.seller_id
         WHERE ${whereSql}
         ${orderSql}
         LIMIT $${pLimit} OFFSET $${pOffset}`;

        const dataRes = await db.query(dataSql, dataParams);
        const data = dataRes.rows.map((row) =>
          formatListingCard(row, hasLat ? lat : null, hasLng ? lng : null)
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

  router.get(
    '/:id',
    optionalAuth,
    validate(listingIdParamSchema, 'params'),
    validate(getListingQuerySchema, 'query'),
    async (req, res, next) => {
      try {
        const result = await fetchListingDetail(
          db,
          req.params.id,
          req.user ? req.user.id : null,
          req.query.lat ?? null,
          req.query.lng ?? null
        );
        if (!result || result.detail.status === 'dihapus') {
          return next(Errors.notFound('Listing tidak ditemukan.'));
        }
        return res.json({ data: result.detail });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.post('/', requireAuth, validate(createListingSchema), async (req, res, next) => {
    try {
      const body = req.body;

      if (!req.user.kota || req.user.kota.trim().length === 0) {
        return next(
          Errors.validation('Data tidak valid', [
            { field: 'kota', message: 'Lengkapi kota di profil sebelum menjual tiket.' },
          ])
        );
      }
      if (body.izinkan_wa && (!req.user.no_wa || req.user.no_wa.trim().length === 0)) {
        return next(
          Errors.validation('Data tidak valid', [
            {
              field: 'izinkan_wa',
              message: 'Lengkapi nomor WhatsApp di profil untuk mengaktifkan opsi WhatsApp.',
            },
          ])
        );
      }

      if (new Date(body.waktu_acara).getTime() <= Date.now()) {
        return next(
          Errors.validation('Data tidak valid', [
            { field: 'waktu_acara', message: 'Waktu acara harus di masa depan.' },
          ])
        );
      }

      validateHandoverAndLocation({
        tipe: body.tipe,
        serahTerima: body.serah_terima,
        lokasiPenjualKota: body.lokasi_penjual_kota,
        venueId: body.venue_id,
        venueTeks: body.venue_teks,
        kota: body.kota,
      });

      const eventRes = await db.query(
        'SELECT id, hidden FROM events WHERE id = $1 LIMIT 1',
        [body.event_id]
      );
      const eventRow = eventRes.rows[0];
      if (!eventRow || eventRow.hidden) {
        return next(
          Errors.validation('Data tidak valid', [
            { field: 'event_id', message: 'Event tidak ditemukan.' },
          ])
        );
      }

      let venueRow = null;
      if (body.venue_id) {
        const venueRes = await db.query(
          'SELECT id, nama, kota, lat, lng FROM venues WHERE id = $1 LIMIT 1',
          [body.venue_id]
        );
        venueRow = venueRes.rows[0] || null;
        if (!venueRow) {
          return next(
            Errors.validation('Data tidak valid', [
              { field: 'venue_id', message: 'Venue tidak ditemukan.' },
            ])
          );
        }
      }

      const resolvedKota = (body.kota && body.kota.trim()) || venueRow?.kota;
      const { refLat, refLng } = computeRefCoordinates({
        tipe: body.tipe,
        lokasiPenjualLat: body.lokasi_penjual_lat,
        lokasiPenjualLng: body.lokasi_penjual_lng,
        venue: venueRow,
      });

      const dupRes = await db.query(
        `SELECT id FROM listings
         WHERE seller_id = $1
           AND event_id = $2
           AND COALESCE(venue_id, 0) = COALESCE($3::int, 0)
           AND COALESCE(venue_teks, '') = COALESCE($4, '')
           AND waktu_acara = $5
           AND harga = $6
           AND deleted_at IS NULL
           AND created_at >= now() - interval '10 minutes'
         LIMIT 1`,
        [
          req.user.id,
          body.event_id,
          body.venue_id ?? null,
          body.venue_teks ?? null,
          body.waktu_acara,
          body.harga,
        ]
      );
      if (dupRes.rows.length > 0) {
        return next(
          Errors.conflict('Listing serupa baru saja dibuat dalam 10 menit terakhir.')
        );
      }

      const uniqueHandover = [...new Set(body.serah_terima)];
      const insertRes = await db.query(
        `INSERT INTO listings (
           event_id, seller_id, venue_id, venue_teks, kota, waktu_acara,
           jenis, tipe, seksi, no_kursi, harga, harga_asli,
           jumlah_total, satuan, terikat_nama, serah_terima,
           lokasi_penjual_kota, lokasi_penjual_lat, lokasi_penjual_lng,
           ref_lat, ref_lng, catatan, izinkan_wa
         )
         VALUES (
           $1, $2, $3, $4, $5, $6,
           $7, $8, $9, $10, $11, $12,
           $13, $14, $15, $16,
           $17, $18, $19,
           $20, $21, $22, $23
         )
         RETURNING id`,
        [
          body.event_id,
          req.user.id,
          body.venue_id ?? null,
          body.venue_id ? null : body.venue_teks,
          resolvedKota,
          body.waktu_acara,
          body.jenis,
          body.tipe,
          body.seksi ?? null,
          body.no_kursi ?? null,
          body.harga,
          body.harga_asli ?? null,
          body.jumlah_total,
          body.satuan,
          body.terikat_nama,
          uniqueHandover,
          body.tipe === 'fisik' ? body.lokasi_penjual_kota : null,
          body.tipe === 'fisik' ? (body.lokasi_penjual_lat ?? null) : null,
          body.tipe === 'fisik' ? (body.lokasi_penjual_lng ?? null) : null,
          refLat,
          refLng,
          body.catatan ?? null,
          Boolean(body.izinkan_wa),
        ]
      );

      const newId = insertRes.rows[0].id;
      for (let i = 0; i < body.photos.length; i++) {
        await db.query(
          'INSERT INTO listing_photos (listing_id, url, urutan) VALUES ($1, $2, $3)',
          [newId, body.photos[i], i]
        );
      }

      const created = await fetchListingDetail(db, newId, req.user.id);

      // Kirim notifikasi ke pengguna yang memantau event ini (event_alerts)
      try {
        const subsRes = await db.query(
          `SELECT user_id
           FROM event_alerts
           WHERE event_id = $1 AND is_active = true AND user_id <> $2`,
          [body.event_id, req.user.id]
        );
        if (subsRes.rows.length > 0) {
          const formattedHarga = Number(created.detail.harga)
            .toString()
            .replace(/\B(?=(\d{3})+(?!\d))/g, '.');
          const notifTitle = 'Tiket Baru Tersedia';
          const notifBody = `${created.detail.event.nama} · ${created.detail.jumlah_tersedia} tiket Rp ${formattedHarga} di ${created.detail.venue_nama}`;
          const io = req.app.get('io');

          for (const sub of subsRes.rows) {
            const notifInsert = await db.query(
              `INSERT INTO notifications (user_id, type, title, body, event_id, listing_id)
               VALUES ($1, 'new_ticket', $2, $3, $4, $5)
               RETURNING id, type, title, body, event_id, listing_id, is_read, created_at`,
              [sub.user_id, notifTitle, notifBody, body.event_id, newId]
            );
            if (io && notifInsert.rows[0]) {
              const countRes = await db.query(
                `SELECT COUNT(*)::int AS unread_count
                 FROM notifications
                 WHERE user_id = $1 AND is_read = false`,
                [sub.user_id]
              );
              io.to(`user:${sub.user_id}`).emit('notification:new', {
                notification: {
                  ...notifInsert.rows[0],
                  event_nama: created.detail.event.nama,
                  event_poster_url: created.detail.event.poster_url ?? null,
                },
                unread_count: Number(countRes.rows[0]?.unread_count ?? 1),
              });
            }
          }
        }
      } catch (_) {
        // Kegagalan notifikasi tidak boleh membatalkan pembuatan listing
      }

      return res.status(201).json({ data: created.detail });
    } catch (err) {
      return next(err);
    }
  });

  router.put(
    '/:id',
    requireAuth,
    validate(listingIdParamSchema, 'params'),
    validate(updateListingSchema),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;
        const existingResult = await fetchListingDetail(db, listingId, req.user.id);
        if (!existingResult || existingResult.detail.status === 'dihapus') {
          return next(Errors.notFound('Listing tidak ditemukan.'));
        }

        const existing = existingResult.raw;
        if (existing.seller_id !== req.user.id) {
          return next(Errors.forbidden('Hanya penjual yang dapat mengubah listing ini.'));
        }

        const body = req.body;
        const nextTotal = body.jumlah_total ?? existing.jumlah_total;
        if (nextTotal < existing.jumlah_terjual) {
          return next(
            Errors.validation('Data tidak valid', [
              {
                field: 'jumlah_total',
                message: 'Jumlah total tidak boleh lebih kecil dari jumlah terjual.',
              },
            ])
          );
        }

        const nextWaktu = body.waktu_acara ?? existing.waktu_acara;
        if (new Date(nextWaktu).getTime() <= Date.now()) {
          return next(
            Errors.validation('Data tidak valid', [
              { field: 'waktu_acara', message: 'Waktu acara harus di masa depan.' },
            ])
          );
        }

        const nextIzinkanWa =
          body.izinkan_wa !== undefined ? body.izinkan_wa : existing.izinkan_wa;
        if (nextIzinkanWa && (!req.user.no_wa || req.user.no_wa.trim().length === 0)) {
          return next(
            Errors.validation('Data tidak valid', [
              {
                field: 'izinkan_wa',
                message: 'Lengkapi nomor WhatsApp di profil untuk mengaktifkan opsi WhatsApp.',
              },
            ])
          );
        }

        const nextTipe = body.tipe ?? existing.tipe;
        const nextSerahTerima = body.serah_terima ?? existing.serah_terima;
        const nextLokasiKota =
          body.lokasi_penjual_kota !== undefined
            ? body.lokasi_penjual_kota
            : existing.lokasi_penjual_kota;
        const nextVenueId =
          body.venue_id !== undefined ? body.venue_id : existing.venue_id;
        const nextVenueTeks =
          body.venue_teks !== undefined ? body.venue_teks : existing.venue_teks;
        const nextKota = body.kota !== undefined ? body.kota : existing.kota;

        validateHandoverAndLocation({
          tipe: nextTipe,
          serahTerima: nextSerahTerima,
          lokasiPenjualKota: nextLokasiKota,
          venueId: nextVenueId,
          venueTeks: nextVenueTeks,
          kota: nextKota,
        });

        let venueRow = null;
        if (nextVenueId) {
          const venueRes = await db.query(
            'SELECT id, nama, kota, lat, lng FROM venues WHERE id = $1 LIMIT 1',
            [nextVenueId]
          );
          venueRow = venueRes.rows[0] || null;
          if (!venueRow) {
            return next(
              Errors.validation('Data tidak valid', [
                { field: 'venue_id', message: 'Venue tidak ditemukan.' },
              ])
            );
          }
        }

        const nextPenjualLat =
          body.lokasi_penjual_lat !== undefined
            ? body.lokasi_penjual_lat
            : existing.lokasi_penjual_lat;
        const nextPenjualLng =
          body.lokasi_penjual_lng !== undefined
            ? body.lokasi_penjual_lng
            : existing.lokasi_penjual_lng;
        const { refLat, refLng } = computeRefCoordinates({
          tipe: nextTipe,
          lokasiPenjualLat: nextPenjualLat,
          lokasiPenjualLng: nextPenjualLng,
          venue: venueRow,
        });

        await db.query(
          `UPDATE listings
           SET event_id = $1,
               venue_id = $2,
               venue_teks = $3,
               kota = $4,
               waktu_acara = $5,
               jenis = $6,
               tipe = $7,
               seksi = $8,
               no_kursi = $9,
               harga = $10,
               harga_asli = $11,
               jumlah_total = $12,
               satuan = $13,
               terikat_nama = $14,
               serah_terima = $15,
               lokasi_penjual_kota = $16,
               lokasi_penjual_lat = $17,
               lokasi_penjual_lng = $18,
               ref_lat = $19,
               ref_lng = $20,
               catatan = $21,
               izinkan_wa = $22,
               updated_at = now()
           WHERE id = $23`,
          [
            body.event_id ?? existing.event_id,
            nextVenueId ?? null,
            nextVenueId ? null : nextVenueTeks,
            (nextKota && nextKota.trim()) || venueRow?.kota || existing.kota,
            nextWaktu,
            body.jenis ?? existing.jenis,
            nextTipe,
            body.seksi !== undefined ? body.seksi : existing.seksi,
            body.no_kursi !== undefined ? body.no_kursi : existing.no_kursi,
            body.harga ?? existing.harga,
            body.harga_asli !== undefined ? body.harga_asli : existing.harga_asli,
            nextTotal,
            body.satuan !== undefined ? body.satuan : existing.satuan,
            body.terikat_nama ?? existing.terikat_nama,
            [...new Set(nextSerahTerima)],
            nextTipe === 'fisik' ? nextLokasiKota : null,
            nextTipe === 'fisik' ? (nextPenjualLat ?? null) : null,
            nextTipe === 'fisik' ? (nextPenjualLng ?? null) : null,
            refLat,
            refLng,
            body.catatan !== undefined ? body.catatan : existing.catatan,
            nextIzinkanWa,
            listingId,
          ]
        );

        if (body.photos) {
          await db.query('DELETE FROM listing_photos WHERE listing_id = $1', [listingId]);
          for (let i = 0; i < body.photos.length; i++) {
            await db.query(
              'INSERT INTO listing_photos (listing_id, url, urutan) VALUES ($1, $2, $3)',
              [listingId, body.photos[i], i]
            );
          }
        }

        const updated = await fetchListingDetail(db, listingId, req.user.id);
        return res.json({ data: updated.detail });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.patch(
    '/:id/stock',
    requireAuth,
    validate(listingIdParamSchema, 'params'),
    validate(patchStockSchema),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;
        const existingResult = await fetchListingDetail(db, listingId, req.user.id);
        if (!existingResult || existingResult.detail.status === 'dihapus') {
          return next(Errors.notFound('Listing tidak ditemukan.'));
        }
        const existing = existingResult.raw;
        if (existing.seller_id !== req.user.id) {
          return next(Errors.forbidden('Hanya penjual yang dapat mengubah stok.'));
        }
        if (req.body.jumlah_terjual > existing.jumlah_total) {
          return next(
            Errors.validation('Data tidak valid', [
              {
                field: 'jumlah_terjual',
                message: 'Jumlah terjual tidak boleh melebihi jumlah total.',
              },
            ])
          );
        }

        await db.query(
          'UPDATE listings SET jumlah_terjual = $1, updated_at = now() WHERE id = $2',
          [req.body.jumlah_terjual, listingId]
        );

        const updated = await fetchListingDetail(db, listingId, req.user.id);
        return res.json({ data: updated.detail });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.post(
    '/:id/confirm',
    requireAuth,
    validate(listingIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;
        const existingResult = await fetchListingDetail(db, listingId, req.user.id);
        if (!existingResult || existingResult.detail.status === 'dihapus') {
          return next(Errors.notFound('Listing tidak ditemukan.'));
        }
        if (existingResult.raw.seller_id !== req.user.id) {
          return next(Errors.forbidden('Hanya penjual yang dapat mengonfirmasi listing.'));
        }

        const confirmRes = await db.query(
          'UPDATE listings SET confirmed_at = now(), updated_at = now() WHERE id = $1 RETURNING confirmed_at',
          [listingId]
        );

        return res.json({
          data: {
            confirmed_at: confirmRes.rows[0].confirmed_at,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.delete(
    '/:id',
    requireAuth,
    validate(listingIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;
        const existingResult = await fetchListingDetail(db, listingId, req.user.id);
        if (!existingResult || existingResult.detail.status === 'dihapus') {
          return next(Errors.notFound('Listing tidak ditemukan.'));
        }
        if (existingResult.raw.seller_id !== req.user.id) {
          return next(Errors.forbidden('Hanya penjual yang dapat menghapus listing.'));
        }

        await db.query(
          'UPDATE listings SET deleted_at = now(), updated_at = now() WHERE id = $1',
          [listingId]
        );
        return res.status(204).send();
      } catch (err) {
        return next(err);
      }
    }
  );

  router.post(
    '/:id/favorite',
    requireAuth,
    validate(listingIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;
        const listingRes = await db.query(
          `SELECT l.id, l.deleted_at, l.hidden, u.banned_at
           FROM listings l
           JOIN users u ON u.id = l.seller_id
           WHERE l.id = $1`,
          [listingId]
        );
        if (
          listingRes.rows.length === 0 ||
          listingRes.rows[0].deleted_at ||
          listingRes.rows[0].hidden ||
          listingRes.rows[0].banned_at
        ) {
          return next(Errors.notFound('Listing tidak ditemukan.'));
        }

        await db.query(
          `INSERT INTO favorites (user_id, listing_id, created_at)
           VALUES ($1, $2, now())
           ON CONFLICT (user_id, listing_id) DO NOTHING`,
          [req.user.id, listingId]
        );

        return res.json({
          data: {
            is_favorite: true,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.delete(
    '/:id/favorite',
    requireAuth,
    validate(listingIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;

        await db.query(
          `DELETE FROM favorites
           WHERE user_id = $1 AND listing_id = $2`,
          [req.user.id, listingId]
        );

        return res.json({
          data: {
            is_favorite: false,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // GET /api/v1/listings/:id/conversation (Percakapan milik pembeli untuk listing ini)
  router.get(
    '/:id/conversation',
    requireAuth,
    validate(listingIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;
        const currentUserId = req.user.id;

        const convRes = await db.query(
          `SELECT c.id FROM conversations c WHERE c.listing_id = $1 AND c.buyer_id = $2 LIMIT 1`,
          [listingId, currentUserId]
        );
        const convRow = convRes.rows[0];
        if (!convRow) {
          return next(Errors.notFound('Percakapan belum ada.'));
        }

        const conv = await fetchConversationWithDetails(
          db,
          convRow.id,
          currentUserId
        );
        if (!conv) {
          return next(Errors.notFound('Percakapan belum ada.'));
        }

        return res.json({
          data: formatConversation(conv, currentUserId),
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // POST /api/v1/listings/:id/conversations (Mulai chat baru atau lanjutkan yang ada secara atomik)
  router.post(
    '/:id/conversations',
    requireAuth,
    msgLimiter,
    validate(listingIdParamSchema, 'params'),
    validate(postMessageBodySchema, 'body'),
    async (req, res, next) => {
      try {
        const listingId = req.params.id;
        const currentUserId = req.user.id;
        const { isi } = req.body;

        const listingRes = await db.query(
          `SELECT l.id, l.seller_id, l.deleted_at, l.hidden,
                  l.waktu_acara, l.jumlah_total, l.jumlah_terjual,
                  u.banned_at AS seller_banned_at
           FROM listings l
           JOIN users u ON u.id = l.seller_id
           WHERE l.id = $1
           LIMIT 1`,
          [listingId]
        );
        const listing = listingRes.rows[0];
        if (
          !listing ||
          listing.deleted_at ||
          listing.hidden ||
          listing.seller_banned_at
        ) {
          return next(Errors.notFound('Listing tidak ditemukan.'));
        }

        // Penjual tidak boleh memulai chat dengan listingnya sendiri (403 FORBIDDEN)
        if (Number(listing.seller_id) === Number(currentUserId)) {
          return next(
            Errors.forbidden(
              'Penjual tidak dapat mengirim pesan pada listing sendiri.'
            )
          );
        }

        // Penjual memblokir pembeli atau sebaliknya -> 403 BLOCKED (BR-12)
        const isBlocked = await checkBlockBetween(
          db,
          currentUserId,
          listing.seller_id
        );
        if (isBlocked) {
          return next(
            Errors.blocked('Tidak dapat mengirim pesan karena pemblokiran.')
          );
        }

        const preview = isi.slice(0, 80);

        // Periksa apakah percakapan antara pembeli dan listing ini sudah ada
        const existingConvRes = await db.query(
          'SELECT id FROM conversations WHERE listing_id = $1 AND buyer_id = $2 LIMIT 1',
          [listingId, currentUserId]
        );
        const existingConv = existingConvRes.rows[0];

        let conversationId;
        if (existingConv) {
          conversationId = existingConv.id;

          const insertMsgSql = `
            INSERT INTO messages (conversation_id, sender_id, isi, created_at)
            VALUES ($1, $2, $3, now())
            RETURNING id, conversation_id, sender_id, isi, created_at
          `;
          const msgRes = await db.query(insertMsgSql, [
            conversationId,
            currentUserId,
            isi,
          ]);
          const createdMessage = msgRes.rows[0];

          await db.query(
            `UPDATE conversations
             SET last_message_at = now(),
                 last_message_preview = $2,
                 buyer_last_read_at = now()
             WHERE id = $1`,
            [conversationId, preview]
          );

          const fullConv = await fetchConversationWithDetails(
            db,
            conversationId,
            currentUserId
          );

          // Siarkan realtime event message:new dan unread:update ke penjual
          const io = req.app.get('io');
          if (io) {
            try {
              const lawanBelumDibacaRes = await db.query(
                `SELECT count(*)::int AS count FROM messages m
                 JOIN conversations c ON c.id = m.conversation_id
                 WHERE m.conversation_id = $1
                   AND m.sender_id <> $2
                   AND m.created_at > COALESCE(
                     CASE WHEN c.buyer_id = $2 THEN c.buyer_last_read_at ELSE c.seller_last_read_at END,
                     '1970-01-01'::timestamptz
                   )`,
                [conversationId, listing.seller_id]
              );
              const belumDibacaLawan = lawanBelumDibacaRes.rows[0]
                ? Number(lawanBelumDibacaRes.rows[0].count)
                : 1;
              const unreadChatsLawan = await countUnreadChats(
                db,
                listing.seller_id
              );

              emitMessageNew(io, {
                lawanId: Number(listing.seller_id),
                message: formatMessage(createdMessage),
                conversationId: Number(conversationId),
                belumDibacaLawan,
                unreadChatsLawan,
              });
            } catch {
              // Abaikan kegagalan broadcast agar respon HTTP tetap sukses
            }
          }

          return res.status(201).json({
            data: {
              conversation: formatConversation(fullConv, currentUserId),
              message: formatMessage(createdMessage),
            },
          });
        } else {
          // Percakapan baru: periksa status listing harus 'tersedia'
          const listingStatus = computeListingStatus({
            deleted_at: listing.deleted_at,
            hidden: listing.hidden,
            waktu_acara: listing.waktu_acara,
            jumlah_total: listing.jumlah_total,
            jumlah_terjual: listing.jumlah_terjual,
          });

          if (listingStatus !== 'tersedia') {
            return next(
              Errors.conflict(
                'Percakapan baru hanya dapat dimulai untuk tiket yang masih tersedia.'
              )
            );
          }

          const insertConvSql = `
            INSERT INTO conversations (
              listing_id, buyer_id, seller_id,
              last_message_at, last_message_preview, buyer_last_read_at
            )
            VALUES ($1, $2, $3, now(), $4, now())
            RETURNING id
          `;
          const convInsertRes = await db.query(insertConvSql, [
            listingId,
            currentUserId,
            listing.seller_id,
            preview,
          ]);
          conversationId = convInsertRes.rows[0].id;

          const insertMsgSql = `
            INSERT INTO messages (conversation_id, sender_id, isi, created_at)
            VALUES ($1, $2, $3, now())
            RETURNING id, conversation_id, sender_id, isi, created_at
          `;
          const msgRes = await db.query(insertMsgSql, [
            conversationId,
            currentUserId,
            isi,
          ]);
          const createdMessage = msgRes.rows[0];

          const fullConv = await fetchConversationWithDetails(
            db,
            conversationId,
            currentUserId
          );

          // Siarkan realtime event message:new dan unread:update ke penjual
          const io = req.app.get('io');
          if (io) {
            try {
              const unreadChatsLawan = await countUnreadChats(
                db,
                listing.seller_id
              );

              emitMessageNew(io, {
                lawanId: Number(listing.seller_id),
                message: formatMessage(createdMessage),
                conversationId: Number(conversationId),
                belumDibacaLawan: 1,
                unreadChatsLawan,
              });
            } catch {
              // Abaikan kegagalan broadcast agar respon HTTP tetap sukses
            }
          }

          return res.status(201).json({
            data: {
              conversation: formatConversation(fullConv, currentUserId),
              message: formatMessage(createdMessage),
            },
          });
        }
      } catch (err) {
        return next(err);
      }
    }
  );

  return router;
}

module.exports = {
  createListingsRouter,
  computeListingStatus,
  computeDiscountPercent,
  computeRefCoordinates,
  formatListingCard,
  getWibDateRange,
  haversineKm,
};

