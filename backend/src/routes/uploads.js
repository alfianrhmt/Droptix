'use strict';

const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');
const { Errors } = require('../utils/errors');

const MAX_UPLOAD_BYTES = 2 * 1024 * 1024;

/**
 * Mendeteksi format gambar dari magic bytes isi berkas (JPG, PNG, WebP).
 */
function detectImageExtension(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 12) {
    return null;
  }
  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return '.jpg';
  }
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return '.png';
  }
  // WebP: RIFF....WEBP
  if (
    buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
    buffer.subarray(8, 12).toString('ascii') === 'WEBP'
  ) {
    return '.webp';
  }
  return null;
}

/**
 * Router unggahan gambar poster / foto tiket.
 */
function createUploadsRouter(requireAuth, uploadsDir) {
  const router = express.Router();
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: MAX_UPLOAD_BYTES },
  });

  const handleMulter = (req, res, next) => {
    upload.single('file')(req, res, (err) => {
      if (!err) return next();
      if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
        return next(
          Errors.validation('Data tidak valid', [
            { field: 'file', message: 'Ukuran berkas maksimal 2 MB.' },
          ])
        );
      }
      return next(
        Errors.validation('Data tidak valid', [
          { field: 'file', message: 'Berkas unggahan tidak valid.' },
        ])
      );
    });
  };

  router.post('/', requireAuth, handleMulter, async (req, res, next) => {
    try {
      if (!req.file || !req.file.buffer) {
        return next(
          Errors.validation('Data tidak valid', [
            { field: 'file', message: 'Berkas gambar wajib diunggah.' },
          ])
        );
      }

      const ext = detectImageExtension(req.file.buffer);
      if (!ext) {
        return next(
          Errors.validation('Data tidak valid', [
            { field: 'file', message: 'Format berkas harus JPG, PNG, atau WebP.' },
          ])
        );
      }

      await fs.mkdir(uploadsDir, { recursive: true });
      const filename = `${crypto.randomBytes(16).toString('hex')}${ext}`;
      await fs.writeFile(path.join(uploadsDir, filename), req.file.buffer);

      return res.status(201).json({
        data: {
          url: `/uploads/${filename}`,
        },
      });
    } catch (err) {
      return next(err);
    }
  });

  return router;
}

module.exports = { createUploadsRouter, detectImageExtension, MAX_UPLOAD_BYTES };

