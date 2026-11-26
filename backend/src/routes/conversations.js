'use strict';

const express = require('express');
const { z } = require('zod');
const { validate } = require('../middleware/validate');
const { Errors } = require('../utils/errors');
const { chatMessageLimiter } = require('../middleware/rateLimit');
const { computeListingStatus } = require('../utils/status');
const { emitMessageNew, emitUnreadUpdate } = require('../realtime');
const { normalizeWaNumber } = require('../utils/phone');

const conversationIdParamSchema = z.object({
  id: z.coerce.number().int().positive('ID percakapan tidak valid.'),
});

const getConversationsQuerySchema = z.object({
  page: z.coerce.number().int().min(1).optional().default(1),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

const getMessagesQuerySchema = z.object({
  before: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(30),
});

const postMessageBodySchema = z.object({
  isi: z
    .string({ required_error: 'Pesan wajib diisi.' })
    .trim()
    .min(1, 'Pesan minimal 1 karakter.')
    .max(1000, 'Pesan maksimal 1000 karakter.'),
});

function formatConversation(row, currentUserId) {
  const isBuyer = Number(currentUserId) === Number(row.buyer_id);
  const status = computeListingStatus({
    deleted_at: row.listing_deleted_at,
    hidden: row.listing_hidden,
    waktu_acara: row.listing_waktu_acara,
    jumlah_total: row.listing_jumlah_total,
    jumlah_terjual: row.listing_jumlah_terjual,
  });

  return {
    id: Number(row.id),
    listing: {
      id: Number(row.listing_id),
      judul: row.event_nama || row.listing_judul || '',
      poster_url: row.event_poster_url || null,
      harga: Number(row.listing_harga),
      status,
    },
    lawan: {
      id: isBuyer ? Number(row.seller_id) : Number(row.buyer_id),
      nama: isBuyer ? row.seller_nama : row.buyer_nama,
      username: isBuyer ? row.seller_username : row.buyer_username,
    },
    peran: isBuyer ? 'pembeli' : 'penjual',
    pesan_terakhir: row.last_message_preview || null,
    waktu_pesan_terakhir: row.last_message_at
      ? new Date(row.last_message_at).toISOString()
      : null,
    belum_dibaca: Number(row.belum_dibaca || 0),
    izinkan_wa: Boolean(row.listing_izinkan_wa),
  };
}

function formatMessage(row) {
  return {
    id: Number(row.id),
    conversation_id: Number(row.conversation_id),
    sender_id: Number(row.sender_id),
    isi: row.isi,
    created_at: new Date(row.created_at).toISOString(),
  };
}

async function countUnreadChats(db, userId) {
  const sql = `
    SELECT count(*)::int AS chats
    FROM conversations c
    WHERE (c.buyer_id = $1 OR c.seller_id = $1)
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE b.blocker_id = $1
          AND b.blocked_id = (CASE WHEN c.buyer_id = $1 THEN c.seller_id ELSE c.buyer_id END)
      )
      AND (
        (c.buyer_id = $1 AND EXISTS (
          SELECT 1 FROM messages m
          WHERE m.conversation_id = c.id
            AND m.sender_id <> $1
            AND m.created_at > COALESCE(c.buyer_last_read_at, '1970-01-01'::timestamptz)
        ))
        OR
        (c.seller_id = $1 AND EXISTS (
          SELECT 1 FROM messages m
          WHERE m.conversation_id = c.id
            AND m.sender_id <> $1
            AND m.created_at > COALESCE(c.seller_last_read_at, '1970-01-01'::timestamptz)
        ))
      )
  `;
  const { rows } = await db.query(sql, [userId]);
  return rows[0] ? Number(rows[0].chats) : 0;
}

async function fetchConversationWithDetails(db, conversationId, currentUserId) {
  const sql = `
    SELECT c.*,
           l.id AS listing_id, l.harga AS listing_harga, l.deleted_at AS listing_deleted_at,
           l.hidden AS listing_hidden, l.waktu_acara AS listing_waktu_acara,
           l.jumlah_total AS listing_jumlah_total, l.jumlah_terjual AS listing_jumlah_terjual,
           l.izinkan_wa AS listing_izinkan_wa,
           e.nama AS event_nama, e.poster_url AS event_poster_url,
           ub.nama AS buyer_nama, ub.username AS buyer_username, ub.banned_at AS buyer_banned_at,
           us.nama AS seller_nama, us.username AS seller_username, us.banned_at AS seller_banned_at,
           (SELECT count(*)::int FROM messages m
            WHERE m.conversation_id = c.id
              AND m.sender_id <> $2
              AND m.created_at > COALESCE(
                CASE WHEN c.buyer_id = $2 THEN c.buyer_last_read_at ELSE c.seller_last_read_at END,
                '1970-01-01'::timestamptz
              )) AS belum_dibaca
    FROM conversations c
    JOIN listings l ON l.id = c.listing_id
    JOIN events e ON e.id = l.event_id
    JOIN users ub ON ub.id = c.buyer_id
    JOIN users us ON us.id = c.seller_id
    WHERE c.id = $1
    LIMIT 1
  `;
  const { rows } = await db.query(sql, [conversationId, currentUserId]);
  return rows[0] || null;
}

async function checkBlockBetween(db, userA, userB) {
  const sql = `
    SELECT 1 FROM blocks
    WHERE (blocker_id = $1 AND blocked_id = $2)
       OR (blocker_id = $2 AND blocked_id = $1)
    LIMIT 1
  `;
  const { rows } = await db.query(sql, [userA, userB]);
  return rows.length > 0;
}

function createConversationsRouter(db, requireAuth, useRateLimit = true) {
  const router = express.Router();

  const msgLimiter = useRateLimit
    ? chatMessageLimiter
    : (_req, _res, next) => next();

  // GET /api/v1/conversations (Kotak masuk chat pengguna)
  router.get(
    '/',
    requireAuth,
    validate(getConversationsQuerySchema, 'query'),
    async (req, res, next) => {
      try {
        const { page, limit } = req.query;
        const offset = (page - 1) * limit;
        const currentUserId = req.user.id;

        // Query total count
        const countSql = `
          SELECT count(*)::int AS total
          FROM conversations c
          WHERE (c.buyer_id = $1 OR c.seller_id = $1)
            AND NOT EXISTS (
              SELECT 1 FROM blocks b
              WHERE b.blocker_id = $1
                AND b.blocked_id = (CASE WHEN c.buyer_id = $1 THEN c.seller_id ELSE c.buyer_id END)
            )
        `;
        const countResult = await db.query(countSql, [currentUserId]);
        const total = countResult.rows[0] ? Number(countResult.rows[0].total) : 0;

        // Query conversations
        const listSql = `
          SELECT c.*,
                 l.id AS listing_id, l.harga AS listing_harga, l.deleted_at AS listing_deleted_at,
                 l.hidden AS listing_hidden, l.waktu_acara AS listing_waktu_acara,
                 l.jumlah_total AS listing_jumlah_total, l.jumlah_terjual AS listing_jumlah_terjual,
                 l.izinkan_wa AS listing_izinkan_wa,
                 e.nama AS event_nama, e.poster_url AS event_poster_url,
                 ub.nama AS buyer_nama, ub.username AS buyer_username, ub.banned_at AS buyer_banned_at,
                 us.nama AS seller_nama, us.username AS seller_username, us.banned_at AS seller_banned_at,
                 (SELECT count(*)::int FROM messages m
                  WHERE m.conversation_id = c.id
                    AND m.sender_id <> $1
                    AND m.created_at > COALESCE(
                      CASE WHEN c.buyer_id = $1 THEN c.buyer_last_read_at ELSE c.seller_last_read_at END,
                      '1970-01-01'::timestamptz
                    )) AS belum_dibaca
          FROM conversations c
          JOIN listings l ON l.id = c.listing_id
          JOIN events e ON e.id = l.event_id
          JOIN users ub ON ub.id = c.buyer_id
          JOIN users us ON us.id = c.seller_id
          WHERE (c.buyer_id = $1 OR c.seller_id = $1)
            AND NOT EXISTS (
              SELECT 1 FROM blocks b
              WHERE b.blocker_id = $1
                AND b.blocked_id = (CASE WHEN c.buyer_id = $1 THEN c.seller_id ELSE c.buyer_id END)
            )
          ORDER BY c.last_message_at DESC NULLS LAST, c.id DESC
          LIMIT $2 OFFSET $3
        `;
        const { rows } = await db.query(listSql, [currentUserId, limit, offset]);

        return res.json({
          data: rows.map((r) => formatConversation(r, currentUserId)),
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

  // GET /api/v1/conversations/:id (Detail satu percakapan)
  router.get(
    '/:id',
    requireAuth,
    validate(conversationIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const conversationId = req.params.id;
        const currentUserId = req.user.id;

        const conv = await fetchConversationWithDetails(
          db,
          conversationId,
          currentUserId
        );
        if (!conv) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        // Hanya peserta yang bisa melihat percakapan
        if (
          Number(conv.buyer_id) !== Number(currentUserId) &&
          Number(conv.seller_id) !== Number(currentUserId)
        ) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        return res.json({
          data: formatConversation(conv, currentUserId),
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // GET /api/v1/conversations/:id/messages (Riwayat pesan berpaginasi before)
  router.get(
    '/:id/messages',
    requireAuth,
    validate(conversationIdParamSchema, 'params'),
    validate(getMessagesQuerySchema, 'query'),
    async (req, res, next) => {
      try {
        const conversationId = req.params.id;
        const currentUserId = req.user.id;
        const { before, limit } = req.query;

        // Verifikasi kepesertaan
        const convResult = await db.query(
          'SELECT buyer_id, seller_id FROM conversations WHERE id = $1 LIMIT 1',
          [conversationId]
        );
        const conv = convResult.rows[0];
        if (
          !conv ||
          (Number(conv.buyer_id) !== Number(currentUserId) &&
            Number(conv.seller_id) !== Number(currentUserId))
        ) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        let msgSql = `
          SELECT id, conversation_id, sender_id, isi, created_at
          FROM messages
          WHERE conversation_id = $1
        `;
        const params = [conversationId];

        if (before) {
          params.push(before);
          msgSql += ` AND id < $${params.length}`;
        }

        params.push(limit + 1);
        msgSql += ` ORDER BY id DESC LIMIT $${params.length}`;

        const msgResult = await db.query(msgSql, params);
        const hasMore = msgResult.rows.length > limit;
        const rows = hasMore ? msgResult.rows.slice(0, limit) : msgResult.rows;

        return res.json({
          data: rows.map(formatMessage),
          meta: {
            ada_lebih_lama: hasMore,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // POST /api/v1/conversations/:id/messages (Kirim pesan dalam percakapan yang ada)
  router.post(
    '/:id/messages',
    requireAuth,
    msgLimiter,
    validate(conversationIdParamSchema, 'params'),
    validate(postMessageBodySchema, 'body'),
    async (req, res, next) => {
      try {
        const conversationId = req.params.id;
        const currentUserId = req.user.id;
        const { isi } = req.body;

        const convResult = await db.query(
          'SELECT buyer_id, seller_id FROM conversations WHERE id = $1 LIMIT 1',
          [conversationId]
        );
        const conv = convResult.rows[0];
        if (
          !conv ||
          (Number(conv.buyer_id) !== Number(currentUserId) &&
            Number(conv.seller_id) !== Number(currentUserId))
        ) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        const lawanId =
          Number(conv.buyer_id) === Number(currentUserId)
            ? Number(conv.seller_id)
            : Number(conv.buyer_id);

        // Periksa aturan pemblokiran BR-12
        const isBlocked = await checkBlockBetween(db, currentUserId, lawanId);
        if (isBlocked) {
          return next(
            Errors.blocked('Tidak dapat mengirim pesan karena pemblokiran.')
          );
        }

        const preview = isi.slice(0, 80);

        // Simpan pesan
        const insertMsgSql = `
          INSERT INTO messages (conversation_id, sender_id, isi, created_at)
          VALUES ($1, $2, $3, now())
          RETURNING id, conversation_id, sender_id, isi, created_at
        `;
        const insertResult = await db.query(insertMsgSql, [
          conversationId,
          currentUserId,
          isi,
        ]);
        const createdMessage = insertResult.rows[0];

        // Perbarui percakapan dan last_read_at pengirim
        const isBuyer = Number(currentUserId) === Number(conv.buyer_id);
        const updateConvSql = isBuyer
          ? `UPDATE conversations
             SET last_message_at = now(),
                 last_message_preview = $2,
                 buyer_last_read_at = now()
             WHERE id = $1`
          : `UPDATE conversations
             SET last_message_at = now(),
                 last_message_preview = $2,
                 seller_last_read_at = now()
             WHERE id = $1`;

        await db.query(updateConvSql, [conversationId, preview]);

        // Siarkan realtime event message:new dan unread:update ke lawan bicara
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
              [conversationId, lawanId]
            );
            const belumDibacaLawan = lawanBelumDibacaRes.rows[0]
              ? Number(lawanBelumDibacaRes.rows[0].count)
              : 1;
            const unreadChatsLawan = await countUnreadChats(db, lawanId);

            emitMessageNew(io, {
              lawanId,
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
          data: formatMessage(createdMessage),
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // DELETE /api/v1/conversations/:id/messages/:messageId (Hapus pesan milik sendiri)
  router.delete(
    '/:id/messages/:messageId',
    requireAuth,
    validate(
      z.object({
        id: z.coerce.number().int().positive('ID percakapan tidak valid.'),
        messageId: z.coerce.number().int().positive('ID pesan tidak valid.'),
      }),
      'params'
    ),
    async (req, res, next) => {
      try {
        const conversationId = req.params.id;
        const messageId = req.params.messageId;
        const currentUserId = req.user.id;

        const convResult = await db.query(
          'SELECT buyer_id, seller_id FROM conversations WHERE id = $1 LIMIT 1',
          [conversationId]
        );
        const conv = convResult.rows[0];
        if (
          !conv ||
          (Number(conv.buyer_id) !== Number(currentUserId) &&
            Number(conv.seller_id) !== Number(currentUserId))
        ) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        const delResult = await db.query(
          `DELETE FROM messages
           WHERE id = $1 AND conversation_id = $2 AND sender_id = $3
           RETURNING id`,
          [messageId, conversationId, currentUserId]
        );
        if (delResult.rows.length === 0) {
          return next(
            Errors.notFound('Pesan tidak ditemukan atau bukan milik Anda.')
          );
        }

        // Perbarui preview pesan terakhir percakapan
        const latestRes = await db.query(
          `SELECT isi, created_at
           FROM messages
           WHERE conversation_id = $1
           ORDER BY id DESC
           LIMIT 1`,
          [conversationId]
        );
        const latest = latestRes.rows[0];
        await db.query(
          `UPDATE conversations
           SET last_message_preview = $2,
               last_message_at = $3
           WHERE id = $1`,
          [
            conversationId,
            latest ? String(latest.isi).slice(0, 80) : null,
            latest ? latest.created_at : null,
          ]
        );

        const lawanId =
          Number(conv.buyer_id) === Number(currentUserId)
            ? Number(conv.seller_id)
            : Number(conv.buyer_id);

        const io = req.app.get('io');
        if (io) {
          try {
            io.to(`user:${lawanId}`).emit('message:deleted', {
              conversation_id: Number(conversationId),
              message_id: Number(messageId),
            });
          } catch {
            // Abaikan kegagalan broadcast
          }
        }

        return res.json({
          data: {
            id: Number(messageId),
            deleted: true,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // POST /api/v1/conversations/:id/read (Tandai percakapan telah dibaca)
  router.post(
    '/:id/read',
    requireAuth,
    validate(conversationIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const conversationId = req.params.id;
        const currentUserId = req.user.id;

        const convResult = await db.query(
          'SELECT buyer_id, seller_id FROM conversations WHERE id = $1 LIMIT 1',
          [conversationId]
        );
        const conv = convResult.rows[0];
        if (
          !conv ||
          (Number(conv.buyer_id) !== Number(currentUserId) &&
            Number(conv.seller_id) !== Number(currentUserId))
        ) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        const isBuyer = Number(currentUserId) === Number(conv.buyer_id);
        const updateReadSql = isBuyer
          ? 'UPDATE conversations SET buyer_last_read_at = now() WHERE id = $1'
          : 'UPDATE conversations SET seller_last_read_at = now() WHERE id = $1';

        await db.query(updateReadSql, [conversationId]);

        const unreadChats = await countUnreadChats(db, currentUserId);

        // Siarkan unread:update ke pembaca
        const io = req.app.get('io');
        if (io) {
          try {
            emitUnreadUpdate(io, {
              userId: currentUserId,
              chats: unreadChats,
            });
          } catch {
            // Abaikan kegagalan broadcast agar respon HTTP tetap sukses
          }
        }

        return res.json({
          data: {
            belum_dibaca: 0,
            chats_belum_dibaca: unreadChats,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  // POST /api/v1/conversations/:id/whatsapp (Tautan WhatsApp khusus pembeli)
  router.post(
    '/:id/whatsapp',
    requireAuth,
    validate(conversationIdParamSchema, 'params'),
    async (req, res, next) => {
      try {
        const conversationId = req.params.id;
        const currentUserId = req.user.id;

        const convSql = `
          SELECT c.id, c.buyer_id, c.seller_id,
                 l.izinkan_wa AS listing_izinkan_wa, l.waktu_acara AS listing_waktu_acara,
                 e.nama AS event_nama,
                 ub.nama AS buyer_nama,
                 us.nama AS seller_nama, us.no_wa AS seller_no_wa, us.banned_at AS seller_banned_at
          FROM conversations c
          JOIN listings l ON l.id = c.listing_id
          JOIN events e ON e.id = l.event_id
          JOIN users ub ON ub.id = c.buyer_id
          JOIN users us ON us.id = c.seller_id
          WHERE c.id = $1
          LIMIT 1
        `;
        const { rows } = await db.query(convSql, [conversationId]);
        const conv = rows[0];

        if (!conv) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        // Hanya peserta yang bisa mengakses
        if (
          Number(conv.buyer_id) !== Number(currentUserId) &&
          Number(conv.seller_id) !== Number(currentUserId)
        ) {
          return next(Errors.notFound('Percakapan tidak ditemukan.'));
        }

        // Hanya pembeli yang boleh meminta tautan WhatsApp
        if (Number(conv.buyer_id) !== Number(currentUserId)) {
          return next(
            Errors.forbidden('Penjual tidak mengizinkan WhatsApp.')
          );
        }

        // Periksa pemblokiran BR-12
        const isBlocked = await checkBlockBetween(db, conv.buyer_id, conv.seller_id);
        if (isBlocked) {
          return next(
            Errors.blocked('Tidak dapat melanjutkan karena pemblokiran.')
          );
        }

        // Cek izin WA dan ketersediaan no_wa penjual
        const normalizedWa = normalizeWaNumber(conv.seller_no_wa);
        if (!conv.listing_izinkan_wa || !normalizedWa) {
          return next(
            Errors.forbidden('Penjual tidak mengizinkan WhatsApp.')
          );
        }

        const dateStr = formatWibDateTime(conv.listing_waktu_acara);
        const text = `Halo, saya ${conv.buyer_nama} dari Droptix, tertarik dengan tiket ${conv.event_nama} (${dateStr}).`;
        const waUrl = `https://wa.me/${normalizedWa}?text=${encodeURIComponent(text)}`;

        return res.json({
          data: {
            wa_url: waUrl,
          },
        });
      } catch (err) {
        return next(err);
      }
    }
  );

  return router;
}

function formatWibDateTime(dateInput) {
  const d = new Date(dateInput);
  if (isNaN(d.getTime())) return '';
  const utc = d.getTime() + d.getTimezoneOffset() * 60000;
  const wibDate = new Date(utc + 7 * 3600000);

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  const day = wibDate.getDate();
  const monthName = months[wibDate.getMonth()];
  const year = wibDate.getFullYear();
  const hours = String(wibDate.getHours()).padStart(2, '0');
  const minutes = String(wibDate.getMinutes()).padStart(2, '0');

  return `${day} ${monthName} ${year}, ${hours}.${minutes} WIB`;
}

module.exports = {
  createConversationsRouter,
  formatConversation,
  formatMessage,
  countUnreadChats,
  fetchConversationWithDetails,
  checkBlockBetween,
  postMessageBodySchema,
  formatWibDateTime,
};
