'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');

const createReportSchema = z.object({
  target_type: z.enum(['listing', 'event', 'user'], {
    required_error: 'target_type wajib diisi (listing, event, atau user).',
  }),
  target_id: z.coerce
    .number({ required_error: 'target_id wajib diisi.' })
    .int('target_id harus berupa bilangan bulat.')
    .positive('target_id harus berupa angka positif.'),
  alasan: z.enum(['penipuan', 'tiket_palsu', 'spam', 'tidak_pantas', 'lainnya'], {
    required_error: 'alasan wajib diisi.',
  }),
  keterangan: z.string().max(1000, 'keterangan maksimal 1000 karakter.').optional().nullable(),
});

function createReportsRouter(db, requireAuth) {
  const router = express.Router();

  // POST /api/v1/reports
  router.post(
    '/',
    requireAuth,
    validate(createReportSchema),
    async (req, res, next) => {
      try {
        const { target_type, target_id, alasan, keterangan } = req.body;
        const currentUserId = req.user.id;

        // Cek batas harian maksimal 10 laporan per pengguna (PRD BR-11 / API.md)
        const countSql = `
          SELECT count(*)::int AS total
          FROM reports
          WHERE reporter_id = $1
            AND created_at >= now() - interval '24 hours'
        `;
        const countRes = await db.query(countSql, [currentUserId]);
        const dailyCount = countRes.rows[0] ? Number(countRes.rows[0].total) : 0;
        if (dailyCount >= 10) {
          return next(
            Errors.rateLimited('Batas maksimal 10 laporan per hari telah tercapai.')
          );
        }

        // Validasi keberadaan target
        if (target_type === 'listing') {
          const { rows } = await db.query(
            'SELECT id FROM listings WHERE id = $1 LIMIT 1',
            [target_id]
          );
          if (rows.length === 0) {
            return next(Errors.notFound('Listing yang dilaporkan tidak ditemukan.'));
          }
        } else if (target_type === 'event') {
          const { rows } = await db.query(
            'SELECT id FROM events WHERE id = $1 LIMIT 1',
            [target_id]
          );
          if (rows.length === 0) {
            return next(Errors.notFound('Event yang dilaporkan tidak ditemukan.'));
          }
        } else if (target_type === 'user') {
          if (Number(target_id) === Number(currentUserId)) {
            return next(
              Errors.validation('Data tidak valid', [
                { field: 'target_id', message: 'Tidak dapat melaporkan akun sendiri.' },
              ])
            );
          }
          const { rows } = await db.query(
            'SELECT id FROM users WHERE id = $1 LIMIT 1',
            [target_id]
          );
          if (rows.length === 0) {
            return next(Errors.notFound('Pengguna yang dilaporkan tidak ditemukan.'));
          }
        }

        const insertSql = `
          INSERT INTO reports (reporter_id, target_type, target_id, alasan, keterangan, status)
          VALUES ($1, $2, $3, $4, $5, 'baru')
          RETURNING id
        `;
        const insertRes = await db.query(insertSql, [
          currentUserId,
          target_type,
          target_id,
          alasan,
          keterangan ? keterangan.trim() : null,
        ]);

        return res.status(201).json({
          data: {
            id: Number(insertRes.rows[0].id),
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  return router;
}

module.exports = {
  createReportsRouter,
  createReportSchema,
};
