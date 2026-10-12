import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { consultAi } from '../lib/gemini.js';

describe('Task 1: Gemini & Smart Fallback Engine Unit Tests', () => {
  const dummyServices = [
    { id: 'srv-001-rumah', nama_layanan: 'Pembersihan Rumah', kategori: 'rumah', tarif_dasar: 120000, durasi_estimasi: '2 - 3 Jam' },
    { id: 'srv-002-kos', nama_layanan: 'Pembersihan Kos', kategori: 'kos', tarif_dasar: 60000, durasi_estimasi: '1 - 2 Jam' },
    { id: 'srv-003-kantor', nama_layanan: 'Pembersihan Kantor', kategori: 'kantor', tarif_dasar: 180000, durasi_estimasi: '2 - 4 Jam' },
    { id: 'srv-004-renov', nama_layanan: 'Pembersihan Pasca Renovasi', kategori: 'renovasi', tarif_dasar: 250000, durasi_estimasi: '3 - 5 Jam' },
  ];

  it('1. Mengembalikan rekomendasi Pembersihan Kos saat pesan mengandung kata kunci kos', async () => {
    const res = await consultAi({
      message: 'Kamar kos saya berantakan banyak debu setelah libur panjang',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.reply.length > 10);
    assert.ok(res.recommendedService);
    assert.equal(res.recommendedService.id, 'srv-002-kos');
    assert.equal(res.recommendedService.suggested_duration, 1);
    assert.ok(Array.isArray(res.suggestedReplies));
    assert.ok(res.suggestedReplies.length > 0);
  });

  it('2. Mengembalikan rekomendasi Pembersihan Rumah dengan durasi 3 jam untuk rumah 2 lantai', async () => {
    const res = await consultAi({
      message: 'Saya punya rumah 2 lantai luas yang kotor habis acara arisan',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.recommendedService);
    assert.equal(res.recommendedService.id, 'srv-001-rumah');
    assert.equal(res.recommendedService.suggested_duration, 3);
  });

  it('3. Menjawab pertanyaan FAQ jam operasional tanpa memaksakan kartu layanan', async () => {
    const res = await consultAi({
      message: 'Jam berapa layanan Resik.in mulai buka dan tutup?',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.reply.includes('08:00'));
    assert.ok(res.reply.includes('17:00'));
    assert.equal(res.recommendedService, null);
  });

  it('4. Menolak dengan santun jika pertanyaan di luar topik kebersihan', async () => {
    const res = await consultAi({
      message: 'Bisa tolong tuliskan resep ayam bakar kecap?',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.reply.toLowerCase().includes('kebersihan') || res.reply.toLowerCase().includes('resik'));
    assert.equal(res.recommendedService, null);
  });
});
