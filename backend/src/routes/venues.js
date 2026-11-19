'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');

const listVenuesQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  kota: z.string().trim().max(60).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
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
      const { q, kota, limit } = req.query;
      const conditions = [];
      const params = [];

      if (q) {
        params.push(`%${q}%`);
        conditions.push(`nama ILIKE $${params.length}`);
      }
      if (kota) {
        params.push(kota);
        conditions.push(`LOWER(kota) = LOWER($${params.length})`);
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      params.push(limit);

      const result = await db.query(
        `SELECT id, nama, kota, alamat, lat, lng
         FROM venues
         ${whereClause}
         ORDER BY nama ASC, id ASC
         LIMIT $${params.length}`,
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

