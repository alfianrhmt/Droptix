'use strict';

const express = require('express');

function createBannersRouter(db) {
  const router = express.Router();

  router.get('/', async (_req, res, next) => {
    try {
      const { rows: banners } = await db.query(
        `SELECT id, type, badge, title, subtitle, cta_label, target_type, target_payload, image_url, gradient_colors, urutan
         FROM banners
         WHERE is_active = true
         ORDER BY urutan ASC, id ASC`
      );

      const hasHype = banners.some((b) => b.type === 'hype_triptych');
      let topPosters = [];
      if (hasHype) {
        const { rows: eventRows } = await db.query(
          `SELECT e.id, e.nama, e.poster_url, COUNT(l.id)::int AS active_listings
           FROM events e
           LEFT JOIN listings l ON l.event_id = e.id AND l.deleted_at IS NULL AND l.hidden = false AND (l.jumlah_total - l.jumlah_terjual) > 0
           WHERE e.hidden = false AND e.poster_url IS NOT NULL
           GROUP BY e.id, e.nama, e.poster_url
           ORDER BY active_listings DESC, e.id DESC
           LIMIT 3`
        );
        topPosters = eventRows.map((r) => ({
          id: r.id,
          nama: r.nama,
          poster_url: r.poster_url,
        }));
      }

      const results = banners.map((b) => {
        if (b.type === 'hype_triptych') {
          return {
            ...b,
            posters: topPosters,
          };
        }
        return b;
      });

      res.json({
        data: results,
      });
    } catch (err) {
      next(err);
    }
  });

  return router;
}

module.exports = { createBannersRouter };
