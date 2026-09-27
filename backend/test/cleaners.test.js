import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';
import { inMemoryStore } from '../lib/supabase.js';

describe('Sprint 2: Cleaners Master Data & Smart Matching API Tests', () => {
  let server;
  let baseUrl;
  let sampleServiceId;

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
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('TC-CLN-01: GET /api/cleaners mengembalikan daftar seluruh petugas aktif (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(Array.isArray(body.data), 'Data harus berupa array');
    assert.ok(body.data.length >= 4, 'Minimal 4 petugas kebersihan');

    const firstCleaner = body.data[0];
    assert.ok(firstCleaner.id);
    assert.ok(firstCleaner.nama);
    assert.ok(Array.isArray(firstCleaner.keahlian));
    assert.ok(firstCleaner.status_operasional);
  });

  it('TC-CLN-02: GET /api/cleaners/:id mengembalikan profil lengkap petugas dengan ulasan (200 OK)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/cln-001`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.id, 'cln-001');
    assert.ok(body.data.nama);
    assert.ok(body.data.foto_url);
    assert.ok(Array.isArray(body.data.keahlian));
    assert.ok(Array.isArray(body.data.ulasan), 'Profil harus menyertakan riwayat ulasan');
  });

  it('TC-CLN-03: GET /api/cleaners/:id mengembalikan 404 jika ID petugas tidak ditemukan', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/cln-nonexistent`);
    assert.equal(res.status, 404);

    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'CLEANER_NOT_FOUND');
  });

  it('TC-CLN-04: GET /api/cleaners/recommendations gagal jika query param wajib tidak lengkap (400 Bad Request)', async () => {
    const res = await fetch(`${baseUrl}/api/cleaners/recommendations?service_id=${sampleServiceId}`);
    assert.equal(res.status, 400);

    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'MISSING_RECOMMENDATION_PARAMS');
  });

  it('TC-CLN-05: GET /api/cleaners/recommendations gagal jika tanggal layanan di masa lampau (400 Bad Request)', async () => {
    const res = await fetch(
      `${baseUrl}/api/cleaners/recommendations?service_id=${sampleServiceId}&tanggal=2020-01-01&start_time=09:00&duration=2`
    );
    assert.equal(res.status, 400);

    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'PAST_DATE_NOT_ALLOWED');
  });

  it('TC-CLN-06: GET /api/cleaners/recommendations mengembalikan daftar kandidat terurut deterministik (200 OK)', async () => {
    const res = await fetch(
      `${baseUrl}/api/cleaners/recommendations?service_id=${sampleServiceId}&tanggal=2026-09-30&start_time=09:00&duration=2`
    );
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(Array.isArray(body.data), 'Rekomendasi berupa array kandidat');
    assert.ok(body.data.length > 0, 'Harus ada kandidat petugas yang memenuhi kriteria');

    const topCandidate = body.data[0];
    assert.ok(topCandidate.cleaner);
    assert.ok(topCandidate.score);
    assert.ok(typeof topCandidate.score.totalScore === 'number');
    assert.ok(topCandidate.score.matchBadge);
    assert.ok(topCandidate.score.skillScore !== undefined);
    assert.ok(topCandidate.score.availScore !== undefined);
  });

  it('TC-CLN-07: POST /api/orders berhasil menyimpan preferensi_petugas_id (201 Created)', async () => {
    const orderPayload = {
      service_id: sampleServiceId,
      preferensi_petugas_id: 'cln-001',
      alamat_lengkap: 'Jl. Gejayan No. 45, Condongcatur, Sleman, DIY',
      patokan_lokasi: 'Samping Apotek K-24',
      luas_area: 'Tipe 45',
      tanggal_layanan: '2026-09-30',
      start_time: '10:00',
      duration: 2
    };

    const res = await fetch(`${baseUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(orderPayload)
    });

    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.success, true);

    // Ambil detail order
    const getRes = await fetch(`${baseUrl}/api/orders/${body.data.id}`);
    const getBody = await getRes.json();
    assert.equal(getBody.data.preferensi_petugas_id, 'cln-001', 'preferensi_petugas_id harus tersimpan');
  });
});
