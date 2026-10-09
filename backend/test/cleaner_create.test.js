import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';
import { db } from '../lib/database.js';

describe('Admin Cleaner Registration API & Store Tests (POST /api/cleaners)', () => {
  let server;
  let baseUrl;
  let createdCleanerId;

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

  it('TC-CRE-01: Gagal mendaftarkan petugas jika nama kosong atau kurang dari 3 karakter (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'A',
        nomor_kontak: '081234567890',
        keahlian: ['rumah'],
        pengalaman_tahun: 2
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'INVALID_NAME');
  });

  it('TC-CRE-02: Gagal mendaftarkan petugas jika nomor kontak tidak valid (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'Agus Pratama',
        nomor_kontak: '123',
        keahlian: ['rumah'],
        pengalaman_tahun: 2
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'INVALID_CONTACT');
  });

  it('TC-CRE-03: Gagal mendaftarkan petugas jika keahlian kosong atau kategori tidak valid (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'Agus Pratama',
        nomor_kontak: '081234567890',
        keahlian: ['pesawat_terbang'], // Kategori tidak valid
        pengalaman_tahun: 2
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'INVALID_SKILLS');
  });

  it('TC-CRE-04: Gagal mendaftarkan petugas jika pengalaman tahun kurang dari 1 (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'Agus Pratama',
        nomor_kontak: '081234567890',
        keahlian: ['rumah', 'kos'],
        pengalaman_tahun: 0
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'INVALID_EXPERIENCE');
  });

  it('TC-CRE-05: Berhasil mendaftarkan petugas baru dengan data valid (201 Created)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'Rian Kurniawan',
        nomor_kontak: '081234567899',
        keahlian: ['rumah', 'kos', 'kantor'],
        pengalaman_tahun: 3,
        tentang: 'Spesialis deep cleaning rumah dan kantor'
      })
    });

    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.data.id);
    assert.equal(body.data.nama, 'Rian Kurniawan');
    assert.equal(body.data.nomor_kontak, '081234567899');
    assert.deepEqual(body.data.keahlian, ['rumah', 'kos', 'kantor']);
    assert.equal(body.data.pengalaman_tahun, 3);
    assert.equal(body.data.status_operasional, 'Aktif');
    assert.equal(body.data.rating_rata_rata, 5.0);
    assert.equal(body.data.total_ulasan, 0);
    assert.ok(body.data.foto_url, 'Petugas baru wajib memiliki foto_url');
    assert.ok(body.data.account, 'Petugas baru wajib memiliki akun login');
    assert.equal(body.data.account.email, 'riankurniawan@resik.in');
    assert.equal(body.data.account.default_password, 'PetugasResik123!');

    createdCleanerId = body.data.id;
  });

  it('TC-CRE-06: Petugas baru yang terdaftar langsung muncul di GET /api/cleaners (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);

    const found = body.data.find(c => c.id === createdCleanerId);
    assert.ok(found, 'Petugas baru wajib ada di daftar cleaners');
    assert.equal(found.nama, 'Rian Kurniawan');
    assert.equal(found.status_operasional, 'Aktif');
    assert.ok(found.foto_url);
  });

  it('TC-CRE-07: Petugas baru dapat ditemukan via GET /api/cleaners/:id (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/${createdCleanerId}`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.nama, 'Rian Kurniawan');
    assert.equal(body.data.total_ulasan, 0);
    assert.ok(body.data.foto_url);

  });
});
