import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';
import { db } from '../lib/database.js';

describe('Admin Cleaner Status Management API & Store Tests', () => {
  let server;
  let baseUrl;
  let sampleServiceId;
  let targetCleanerId = 'cln-001';

  before(async () => {
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });

    const sRes = await fetch(`${baseUrl}/api/services`);
    const sBody = await sRes.json();
    const serviceRumah = sBody.data.find(s => s.kategori === 'rumah');
    sampleServiceId = serviceRumah?.id || 'srv-001-rumah';

    const cRes = await fetch(`${baseUrl}/api/cleaners`);
    const cBody = await cRes.json();
    if (cBody.data && cBody.data.length > 0) {
      targetCleanerId = cBody.data[0].id;
    }
  });

  after(async () => {
    // Kembalikan cleaner ke status Aktif jika terubah
    await db.updateCleanerStatus(targetCleanerId, 'Aktif');
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('TC-CST-01: Gagal mengubah status jika parameter status_operasional tidak valid (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/${targetCleanerId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status_operasional: 'Izin_Liburan' })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'INVALID_OPERATIONAL_STATUS');
  });

  it('TC-CST-02: Gagal mengubah status jika ID petugas tidak ditemukan (404 Not Found)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/cln-unknown-999/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status_operasional: 'Cuti' })
    });

    assert.equal(res.status, 404);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'CLEANER_NOT_FOUND');
  });

  it('TC-CST-03: Berhasil mengubah status petugas menjadi Cuti (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/${targetCleanerId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status_operasional: 'Cuti' })
    });

    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.id, targetCleanerId);
    assert.equal(body.data.status_operasional, 'Cuti');

    // Verifikasi verifikasi langsung dari db
    const cleaner = await db.getCleanerById(targetCleanerId);
    assert.equal(cleaner.status_operasional, 'Cuti');
  });

  it('TC-CST-04: Petugas berstatus Cuti otomatis tereliminasi dari rekomendasi Smart Matching', async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split('T')[0];

    const res = await fetch(
      `${baseUrl}/api/cleaners/recommendations?service_id=${sampleServiceId}&tanggal=${tomorrowStr}&start_time=09:00&duration=2`
    );
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);

    const candidates = body.data || [];
    const found = candidates.find(c => c.cleaner.id === targetCleanerId);
    assert.equal(found, undefined, 'Petugas Cuti tidak boleh muncul di rekomendasi');
  });

  it('TC-CST-05: Berhasil mengembalikan status petugas menjadi Aktif dan kembali muncul di rekomendasi', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/${targetCleanerId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status_operasional: 'Aktif' })
    });

    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.status_operasional, 'Aktif');

    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split('T')[0];

    const recRes = await fetch(
      `${baseUrl}/api/cleaners/recommendations?service_id=${sampleServiceId}&tanggal=${tomorrowStr}&start_time=09:00&duration=2`
    );
    const recBody = await recRes.json();
    const found = recBody.data.find(c => c.cleaner.id === targetCleanerId);
    assert.ok(found, 'Petugas Aktif harus muncul di rekomendasi');
  });

  it('TC-CST-06: Berhasil mengubah status petugas menjadi Nonaktif (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/${targetCleanerId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status_operasional: 'Nonaktif' })
    });

    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.status_operasional, 'Nonaktif');

    // Kembalikan ke Aktif
    await db.updateCleanerStatus(targetCleanerId, 'Aktif');
  });
});
