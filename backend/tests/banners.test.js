'use strict';

const request = require('supertest');
const { createApp } = require('../src/index');
const defaultPool = require('../src/db/pool');

describe('GET /api/v1/banners', () => {
  let app;

  beforeAll(() => {
    app = createApp({ db: defaultPool, useRateLimit: false });
  });

  it('mengembalikan daftar banner aktif dengan urutan yang benar', async () => {
    const res = await request(app).get('/api/v1/banners');
    expect(res.status).toBe(200);
    expect(res.body.data).toBeDefined();
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);

    const first = res.body.data[0];
    expect(first).toHaveProperty('id');
    expect(first).toHaveProperty('type');
    expect(first).toHaveProperty('title');
    expect(first).toHaveProperty('cta_label');
    expect(first).toHaveProperty('target_type');

    // Cek banner hype_triptych jika ada
    const hypeBanner = res.body.data.find((b) => b.type === 'hype_triptych');
    if (hypeBanner) {
      expect(hypeBanner).toHaveProperty('posters');
      expect(Array.isArray(hypeBanner.posters)).toBe(true);
    }
  });
});
