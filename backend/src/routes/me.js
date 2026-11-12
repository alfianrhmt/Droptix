'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');
const { normalizeWaNumber } = require('../utils/phone');

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

  router.put(
    '/',
    requireAuth,
    validate(updateMeSchema),
    async (req, res, next) => {
      try {
        const { nama, no_wa, kota } = req.body;

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

        const { rows } = await db.query(
          `UPDATE users
           SET nama = $1, no_wa = $2, kota = $3
           WHERE id = $4
           RETURNING id, nama, email, no_wa, kota, created_at`,
          [nextNama, nextWa, nextKota, req.user.id]
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
