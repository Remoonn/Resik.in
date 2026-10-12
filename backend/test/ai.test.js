import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';

describe('Task 2: POST /api/ai/chat API Integration Tests', () => {
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

  it('1. POST /api/ai/chat mengembalikan HTTP 200 dengan balasan terstruktur', async () => {
    const res = await fetch(`${baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Kamar kos saya kotor berdebu setelah pulang kampung',
        history: []
      })
    });

    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.data.reply);
    assert.ok(body.data.recommended_service);
    assert.equal(body.data.recommended_service.kategori, 'kos');
    assert.ok(Array.isArray(body.data.suggested_replies));
  });

  it('2. Menolak request jika pesan kosong dengan HTTP 400', async () => {
    const res = await fetch(`${baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: '   ',
        history: []
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'VALIDATION_ERROR');
  });

  it('3. Menolak request jika pesan melebihi 500 karakter dengan HTTP 400', async () => {
    const longMessage = 'A'.repeat(501);
    const res = await fetch(`${baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: longMessage,
        history: []
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'MESSAGE_TOO_LONG');
  });
});
