'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');

const userIdParamSchema = z.object({
  id: z.coerce
    .number({ required_error: 'ID pengguna wajib diisi.' })
    .int('ID pengguna harus berupa bilangan bulat.')
    .positive('ID pengguna tidak valid.'),
});

function createUsersRouter(db, requireAuth) {
  const router = express.Router();

  // POST /api/v1/users/:id/block (Idempoten; memblokir diri sendiri: 422)
  router.post(
    '/:id/block',
    requireAuth,
    validate(userIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const targetUserId = req.params.id;
        const currentUserId = req.user.id;

        if (Number(targetUserId) === Number(currentUserId)) {
          return next(
            Errors.validation('Data tidak valid', [
              { field: 'id', message: 'Tidak dapat memblokir akun sendiri.' },
            ])
          );
        }

        // Cek apakah pengguna target ada
        const { rows } = await db.query(
          'SELECT id FROM users WHERE id = $1 LIMIT 1',
          [targetUserId]
        );
        if (rows.length === 0) {
          return next(Errors.notFound('Pengguna tidak ditemukan.'));
        }

        await db.query(
          `INSERT INTO blocks (blocker_id, blocked_id)
           VALUES ($1, $2)
           ON CONFLICT (blocker_id, blocked_id) DO NOTHING`,
          [currentUserId, targetUserId]
        );

        return res.json({
          data: {
            blocked: true,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // DELETE /api/v1/users/:id/block (Idempoten)
  router.delete(
    '/:id/block',
    requireAuth,
    validate(userIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const targetUserId = req.params.id;
        const currentUserId = req.user.id;

        await db.query(
          'DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2',
          [currentUserId, targetUserId]
        );

        return res.json({
          data: {
            blocked: false,
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
  createUsersRouter,
  userIdParamSchema,
};
