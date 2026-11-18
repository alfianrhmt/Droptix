'use strict';

class AppError extends Error {
  constructor(status, code, message, details = null, extra = null) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
    this.extra = extra;
  }
}

const Errors = {
  unauthorized: (message = 'Silakan login terlebih dahulu.') =>
    new AppError(401, 'UNAUTHORIZED', message),
  forbidden: (message = 'Kamu tidak punya akses.') =>
    new AppError(403, 'FORBIDDEN', message),
  blocked: (message = 'Tidak dapat melanjutkan karena pemblokiran.') =>
    new AppError(403, 'BLOCKED', message),
  accountBanned: (message = 'Akunmu dibekukan oleh pengelola.') =>
    new AppError(403, 'ACCOUNT_BANNED', message),
  notFound: (message = 'Data tidak ditemukan.') =>
    new AppError(404, 'NOT_FOUND', message),
  conflict: (message = 'Data sudah ada.') =>
    new AppError(409, 'CONFLICT', message),
  similarEvent: (similar) =>
    new AppError(409, 'SIMILAR_EVENT_EXISTS', 'Ada event yang mirip', null, {
      similar,
    }),
  eventLocked: (
    message = 'Event sudah memiliki listing dari penjual lain sehingga tidak dapat diubah.'
  ) => new AppError(403, 'EVENT_LOCKED', message),
  validation: (message = 'Data tidak valid', details = null) =>
    new AppError(422, 'VALIDATION_ERROR', message, details),
  rateLimited: (message = 'Terlalu banyak permintaan. Coba lagi nanti.') =>
    new AppError(429, 'RATE_LIMITED', message),
};

/**
 * Middleware penanganan error seragam sesuai docs/API.md.
 */
function errorHandler(err, _req, res, _next) {
  if (err instanceof AppError) {
    const body = {
      error: {
        code: err.code,
        message: err.message,
        ...(err.details ? { details: err.details } : {}),
        ...(err.extra || {}),
      },
    };
    return res.status(err.status).json(body);
  }

  if (err && err.type === 'entity.parse.failed') {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Format JSON tidak valid.',
      },
    });
  }

  console.error('[error]', err);
  return res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'Terjadi kesalahan pada server.',
    },
  });
}

module.exports = { AppError, Errors, errorHandler };

