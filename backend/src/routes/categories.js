'use strict';

const express = require('express');

/**
 * Router daftar kategori event publik.
 */
function createCategoriesRouter(db) {
  const router = express.Router();

  router.get('/', async (_req, res, next) => {
    try {
      const result = await db.query(
        'SELECT id, slug, nama, ikon, urutan FROM categories ORDER BY urutan ASC, id ASC'
      );
      return res.json({ data: result.rows });
    } catch (err) {
      return next(err);
    }
  });

  return router;
}

module.exports = { createCategoriesRouter };
