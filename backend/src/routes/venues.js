'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');

const listVenuesQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  kota: z.string().trim().max(60).optional(),
  user_kota: z.string().trim().max(60).optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(50),
});

const createVenueBodySchema = z.object({
  nama: z.string().trim().min(2, 'Nama venue minimal 2 karakter').max(120),
  kota: z.string().trim().min(2, 'Kota venue minimal 2 karakter').max(60),
  alamat: z.string().trim().max(255).optional().nullable(),
});

/**
 * Router pencarian dan daftar venue publik.
 */
function createVenuesRouter(db) {
  const router = express.Router();

  router.post('/', validate(createVenueBodySchema, 'body'), async (req, res, next) => {
    try {
      const { nama, kota, alamat } = req.body;

      // Cek apakah venue dengan nama dan kota yang sama sudah ada
      const existing = await db.query(
        'SELECT id, nama, kota, alamat, lat, lng FROM venues WHERE LOWER(nama) = LOWER($1) AND LOWER(kota) = LOWER($2) LIMIT 1',
        [nama, kota]
      );
      if (existing.rows.length > 0) {
        return res.status(200).json({ data: existing.rows[0] });
      }

      const insertResult = await db.query(
        `INSERT INTO venues (nama, kota, alamat)
         VALUES ($1, $2, $3)
         RETURNING id, nama, kota, alamat, lat, lng`,
        [nama, kota, alamat || null]
      );

      return res.status(201).json({ data: insertResult.rows[0] });
    } catch (err) {
      return next(err);
    }
  });

  router.get('/', validate(listVenuesQuerySchema, 'query'), async (req, res, next) => {
    try {
      const { q, kota, user_kota, lat, lng, limit } = req.query;
      const conditions = [];
      const params = [];

      if (q) {
        params.push(`%${q}%`);
        conditions.push(`(nama ILIKE $${params.length} OR kota ILIKE $${params.length})`);
      }
      if (kota) {
        params.push(kota);
        conditions.push(`LOWER(kota) = LOWER($${params.length})`);
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      const orderParts = [];
      if (user_kota) {
        params.push(user_kota);
        orderParts.push(`CASE WHEN LOWER(kota) = LOWER($${params.length}) THEN 0 ELSE 1 END ASC`);
      }
      if (typeof lat === 'number' && typeof lng === 'number') {
        params.push(lat);
        const latParam = params.length;
        params.push(lng);
        const lngParam = params.length;
        orderParts.push(
          `CASE WHEN lat IS NOT NULL AND lng IS NOT NULL THEN (6371 * acos(least(1.0, greatest(-1.0, cos(radians($${latParam})) * cos(radians(lat)) * cos(radians(lng) - radians($${lngParam})) + sin(radians($${latParam})) * sin(radians(lat)))))) ELSE 99999 END ASC`
        );
      }
      orderParts.push('nama ASC', 'id ASC');

      params.push(limit);
      const limitParam = params.length;

      const result = await db.query(
        `SELECT id, nama, kota, alamat, lat, lng
         FROM venues
         ${whereClause}
         ORDER BY ${orderParts.join(', ')}
         LIMIT $${limitParam}`,
        params
      );

      return res.json({ data: result.rows });
    } catch (err) {
      return next(err);
    }
  });

  return router;
}

module.exports = { createVenuesRouter };

