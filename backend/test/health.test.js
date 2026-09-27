import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';

describe('Sprint 0: Health & Service Catalog API Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('1. GET /api/health harus mengembalikan status 200 OK dan status UP', async () => {
    const res = await fetch(`${baseUrl}/api/health`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.status, 'UP');
  });

  it('2. GET /api/services harus mengembalikan 4 kategori layanan kebersihan', async () => {
    const res = await fetch(`${baseUrl}/api/services`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(Array.isArray(body.data), 'Data layanan harus berupa array');
    assert.ok(body.data.length >= 4, 'Minimal terdapat 4 katalog layanan aktif');

    const categories = body.data.map(s => s.kategori);
    assert.ok(categories.includes('rumah'), 'Katalog harus memiliki layanan rumah');
    assert.ok(categories.includes('kos'), 'Katalog harus memiliki layanan kos');
    assert.ok(categories.includes('kantor'), 'Katalog harus memiliki layanan kantor');
    assert.ok(categories.includes('pasca_renovasi'), 'Katalog harus memiliki layanan pasca_renovasi');
  });

  it('3. GET /api/nonexistent harus mengembalikan 404 JSON standard envelope', async () => {
    const res = await fetch(`${baseUrl}/api/nonexistent`);
    assert.equal(res.status, 404);

    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'ENDPOINT_NOT_FOUND');
  });
});
