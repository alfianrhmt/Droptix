'use strict';

const request = require('supertest');
const app = require('../src/index');

describe('GET /api/v1/health', () => {
  it('mengembalikan status ok', async () => {
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });

  it('endpoint tidak ada mengembalikan 404', async () => {
    const res = await request(app).get('/api/v1/nonexistent');
    expect(res.status).toBe(404);
  });
});

