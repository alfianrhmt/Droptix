'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');

const listVenuesQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  kota: z.string().trim().max(60).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

/**
 * Router pencarian dan daftar venue publik.
 */
function createVenuesRouter(db) {
  const router = express.Router();

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

