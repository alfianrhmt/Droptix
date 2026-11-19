'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { signToken } = require('../middleware/auth');
const { Errors } = require('../utils/errors');
const { normalizeWaNumber } = require('../utils/phone');

const registerSchema = z.object({
  nama: z
    .string({ required_error: 'Nama wajib diisi.' })
    .trim()
    .min(2, 'Nama minimal 2 karakter.')
    .max(80, 'Nama maksimal 80 karakter.'),
  email: z
    .string({ required_error: 'Email wajib diisi.' })
    .trim()
    .toLowerCase()
    .email('Format email tidak valid.')
    .max(120, 'Email maksimal 120 karakter.'),
  password: z
    .string({ required_error: 'Password wajib diisi.' })
    .min(8, 'Password minimal 8 karakter.'),
  setuju_syarat: z
    .boolean({ required_error: 'Persetujuan syarat wajib diisi.' })
    .refine((v) => v === true, {
      message: 'Kamu harus menyetujui Syarat Penggunaan dan Kebijakan Privasi.',
    }),
  no_wa: z.string().trim().optional().nullable(),
  kota: z
    .string()
    .trim()
    .min(2, 'Nama kota minimal 2 karakter.')
    .max(60, 'Nama kota maksimal 60 karakter.')
    .optional()
    .nullable(),
});

const loginSchema = z.object({
  email: z
    .string({ required_error: 'Email wajib diisi.' })
    .trim()
    .toLowerCase()
    .email('Format email tidak valid.'),
  password: z
    .string({ required_error: 'Password wajib diisi.' })
    .min(1, 'Password wajib diisi.'),
});

function createAuthRouter(db) {
  const router = express.Router();

  router.post(
    '/register',
    validate(registerSchema),
    async (req, res, next) => {
      try {
        const { nama, email, password, no_wa, kota } = req.body;

        let normalizedWa = null;
        if (no_wa !== undefined && no_wa !== null && no_wa !== '') {
          normalizedWa = normalizeWaNumber(no_wa);
          if (!normalizedWa) {
            return next(
              Errors.validation('Data tidak valid', [
                {
                  field: 'no_wa',
                  message: 'Nomor WhatsApp tidak valid (contoh: 081234567890).',
                },
              ])
            );
          }
        }

        const existing = await db.query(
          'SELECT id FROM users WHERE email = $1 LIMIT 1',
          [email]
        );
        if (existing.rows.length > 0) {
          return next(Errors.conflict('Email sudah terdaftar.'));
        }

        const passwordHash = await bcrypt.hash(password, 10);
        const { rows } = await db.query(
          `INSERT INTO users (nama, email, password_hash, no_wa, kota, setuju_syarat_at)
           VALUES ($1, $2, $3, $4, $5, now())
           RETURNING id, nama, email, no_wa, kota, foto_url`,
          [nama, email, passwordHash, normalizedWa, kota || null]
        );

        const user = {
          ...rows[0],
          foto_url: rows[0].foto_url || null,
        };
        const token = signToken(user);
        return res.status(201).json({ data: { token, user } });
      } catch (err) {
        return next(err);
      }
    }
  );

  router.post('/login', validate(loginSchema), async (req, res, next) => {
    try {
      const { email, password } = req.body;
      const { rows } = await db.query(
        `SELECT id, nama, email, password_hash, no_wa, kota, foto_url, banned_at
         FROM users
         WHERE email = $1
         LIMIT 1`,
        [email]
      );

      if (rows.length === 0) {
        return next(Errors.unauthorized('Email atau password salah.'));
      }

      const row = rows[0];
      const match = await bcrypt.compare(password, row.password_hash);
      if (!match) {
        return next(Errors.unauthorized('Email atau password salah.'));
      }

      if (row.banned_at) {
        return next(Errors.accountBanned());
      }

      const user = {
        id: row.id,
        nama: row.nama,
        email: row.email,
        no_wa: row.no_wa,
        kota: row.kota,
        foto_url: row.foto_url || null,
      };
      const token = signToken(user);
      return res.status(200).json({ data: { token, user } });
    } catch (err) {
      return next(err);
    }
  });

  return router;
}

module.exports = { createAuthRouter };

