import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import app from '../server.js';

let server;
let baseUrl;

test.before(async () => {
  await new Promise((resolve) => {
    server = http.createServer(app);
    server.listen(0, () => {
      const port = server.address().port;
      baseUrl = `http://localhost:${port}`;
      resolve();
    });
  });
});

test.after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('Auth API Test Suite', async (t) => {
  await t.test('TC-AUTH-01: Gagal login jika email atau password kosong (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: '' })
    });

    assert.equal(res.status, 400);
    const json = await res.json();
    assert.equal(json.success, false);
    assert.match(json.message, /wajib diisi/i);
  });

  await t.test('TC-AUTH-02: Gagal login jika kredensial salah (401 Unauthorized)', async () => {
    const res = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'salah@resik.in', password: 'wrongpassword' })
    });

    assert.equal(res.status, 401);
    const json = await res.json();
    assert.equal(json.success, false);
    assert.match(json.message, /salah/i);
  });

  await t.test('TC-AUTH-03: Berhasil login sebagai Pelanggan (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'pelanggan@resik.in', password: 'password123' })
    });

    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.user.role, 'customer');
    assert.equal(json.data.user.email, 'pelanggan@resik.in');
    assert.ok(json.data.token);
  });

  await t.test('TC-AUTH-04: Berhasil login sebagai Petugas/Cleaner (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'petugas@resik.in', password: 'password123' })
    });

    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.user.role, 'cleaner');
    assert.equal(json.data.user.cleaner_id, 'cln-001');
  });

  await t.test('TC-AUTH-05: Berhasil login sebagai Admin (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'admin@resik.in', password: 'password123' })
    });

    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.user.role, 'admin');
  });

  await t.test('TC-AUTH-06: Gagal registrasi jika password < 6 karakter (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'User Baru',
        email: 'userbaru@resik.in',
        password: '123'
      })
    });

    assert.equal(res.status, 400);
    const json = await res.json();
    assert.equal(json.success, false);
    assert.match(json.message, /minimal 6/i);
  });

  await t.test('TC-AUTH-07: Berhasil registrasi akun baru (201 Created)', async () => {
    const uniqueEmail = `test.${Date.now()}@resik.in`;
    const res = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'Ahmad Dahlan',
        email: uniqueEmail,
        password: 'password123',
        nomor_wa: '081299998888',
        role: 'customer'
      })
    });

    assert.equal(res.status, 201);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.user.email, uniqueEmail);
    assert.equal(json.data.user.nama, 'Ahmad Dahlan');
    assert.ok(json.data.token);
  });
});
