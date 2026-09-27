import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  hasScheduleConflict,
  calculateSkillScore,
  calculateAvailabilityScore,
  calculateRatingScore,
  calculateExperienceScore,
  calculateMatchingScore,
  getRecommendations
} from '../lib/matching.js';

describe('Sprint 2: Deterministic Smart Matching Engine Unit Tests', () => {
  const sampleCleaners = [
    {
      id: 'cln-001',
      nama_lengkap: 'Budi Santoso',
      status_operasional: 'Aktif',
      rating_rata_rata: 4.9,
      total_ulasan: 124,
      total_pekerjaan: 142,
      pengalaman_tahun: 4,
      keahlian: ['pembersihan_rumah', 'pembersihan_kos', 'deep_cleaning'],
      foto_url: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400'
    },
    {
      id: 'cln-002',
      nama_lengkap: 'Siti Aminah',
      status_operasional: 'Aktif',
      rating_rata_rata: 4.8,
      total_ulasan: 89,
      total_pekerjaan: 98,
      pengalaman_tahun: 3,
      keahlian: ['pembersihan_rumah', 'pembersihan_kantor', 'pembersihan_kos'],
      foto_url: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400'
    },
    {
      id: 'cln-003',
      nama_lengkap: 'Joko Prabowo',
      status_operasional: 'Aktif',
      rating_rata_rata: 5.0,
      total_ulasan: 210,
      total_pekerjaan: 230,
      pengalaman_tahun: 6,
      keahlian: ['pembersihan_rumah', 'pembersihan_kantor', 'pasca_renovasi'],
      foto_url: 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400'
    },
    {
      id: 'cln-004',
      nama_lengkap: 'Rian Pratama',
      status_operasional: 'Cuti', // Non-aktif / cuti
      rating_rata_rata: 4.7,
      total_ulasan: 45,
      total_pekerjaan: 50,
      pengalaman_tahun: 2,
      keahlian: ['pembersihan_rumah'],
      foto_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400'
    },
    {
      id: 'cln-005',
      nama_lengkap: 'Dewi Lestari', // Petugas Baru (Provisional Rating)
      status_operasional: 'Aktif',
      rating_rata_rata: 0,
      total_ulasan: 0,
      total_pekerjaan: 0,
      pengalaman_tahun: 1,
      keahlian: ['pembersihan_rumah', 'pembersihan_kos'],
      foto_url: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400'
    }
  ];

  it('TC-MTG-01: Hard Filter mengeliminasi petugas dengan status_operasional != Aktif', () => {
    const service = { kategori: 'rumah' };
    const date = '2026-09-30';
    const startTime = '09:00';
    const duration = 2;
    const existingOrders = [];

    const recommendations = getRecommendations({
      cleaners: sampleCleaners,
      service,
      date,
      startTime,
      duration,
      existingOrders
    });

    const hasCutiCleaner = recommendations.some(r => r.cleaner.id === 'cln-004');
    assert.equal(hasCutiCleaner, false, 'Petugas berstatus Cuti wajib dieliminasi oleh Hard Filter');
  });

  it('TC-MTG-02: Hard Filter mengeliminasi petugas dengan bentrok jadwal termasuk buffer 30 menit', () => {
    // cln-001 memiliki pesanan pukul 11:30 - 13:30
    // Pesanan baru yang diajukan: 09:00 - 11:15 (selesai 11:15 + buffer 30 menit = 11:45 -> BENTROK)
    const existingOrders = [
      {
        id: 'ord-existing-1',
        cleaner_id: 'cln-001',
        tanggal_layanan: '2026-09-30',
        start_time: '11:30',
        end_time: '13:30',
        status_pekerjaan: 'Dikonfirmasi'
      }
    ];

    const conflictDirect = hasScheduleConflict('cln-001', '2026-09-30', '11:00', 2, existingOrders, 30);
    assert.equal(conflictDirect, true, 'Harus bentrok karena overlap langsung');

    const conflictBuffer = hasScheduleConflict('cln-001', '2026-09-30', '09:00', 2.25, existingOrders, 30);
    // 09:00 + 2h15m = 11:15. Buffer sampai 11:45. Existing start 11:30 -> OVERLAP BUFFER
    assert.equal(conflictBuffer, true, 'Harus bentrok karena melanggar buffer 30 menit');

    const safeSchedule = hasScheduleConflict('cln-001', '2026-09-30', '08:00', 2, existingOrders, 30);
    // 08:00 + 2h = 10:00. Buffer sampai 10:30. Existing start 11:30 -> AMAN (>30m)
    assert.equal(safeSchedule, false, 'Harus aman karena selisih jeda >= 30 menit');
  });

  it('TC-MTG-03: Hard Filter mengeliminasi petugas tanpa keahlian pasca_renovasi untuk layanan renovasi', () => {
    const serviceRenovasi = { kategori: 'pasca_renovasi' };
    const recommendations = getRecommendations({
      cleaners: sampleCleaners,
      service: serviceRenovasi,
      date: '2026-09-30',
      startTime: '08:00',
      duration: 4,
      existingOrders: []
    });

    // Hanya cln-003 yang punya keahlian 'pasca_renovasi'
    assert.equal(recommendations.length, 1);
    assert.equal(recommendations[0].cleaner.id, 'cln-003');
    assert.equal(recommendations[0].cleaner.nama_lengkap, 'Joko Prabowo');
  });

  it('TC-MTG-04: Kalkulasi skor 40/30/20/10 deterministik secara akurat', () => {
    // cln-001:
    // skill match 'pembersihan_rumah' -> 100 * 0.40 = 40.0
    // availability 0 existing orders -> 100 * 0.30 = 30.0
    // rating 4.9 -> (4.9 / 5.0) * 100 = 98.0 * 0.20 = 19.6
    // exp 4 tahun -> (4 / 5) * 100 = 80.0 * 0.10 = 8.0
    // Total = 40.0 + 30.0 + 19.6 + 8.0 = 97.6
    const score = calculateMatchingScore(
      sampleCleaners[0],
      { kategori: 'rumah' },
      '2026-09-30',
      '09:00',
      2,
      []
    );

    assert.equal(score.skillScore, 100);
    assert.equal(score.availScore, 100);
    assert.equal(score.ratingScore, 98);
    assert.equal(score.expScore, 80);
    assert.equal(score.totalScore, 97.6);
    assert.equal(score.matchBadge, 'Sangat Direkomendasikan');
    assert.equal(score.isProvisionalRating, false);
  });

  it('TC-MTG-05: Provisional Rating (4.5) diterapkan secara transparan untuk petugas baru', () => {
    // cln-005 (Dewi Lestari, 0 review, 0 order, exp 1 thn):
    // skill match 'pembersihan_rumah' -> 100 * 0.40 = 40.0
    // avail 0 orders -> 100 * 0.30 = 30.0
    // rating provisional 4.5 -> (4.5 / 5.0) * 100 = 90.0 * 0.20 = 18.0
    // exp 1 thn -> (1 / 5) * 100 = 20.0 * 0.10 = 2.0
    // Total = 40.0 + 30.0 + 18.0 + 2.0 = 90.0
    const score = calculateMatchingScore(
      sampleCleaners[4],
      { kategori: 'rumah' },
      '2026-09-30',
      '09:00',
      2,
      []
    );

    assert.equal(score.isProvisionalRating, true);
    assert.equal(score.effectiveRating, 4.5);
    assert.equal(score.ratingScore, 90.0);
    assert.equal(score.totalScore, 90.0);
  });

  it('TC-MTG-06: Tie-Breaking berurutan: rating DESC -> total_pekerjaan DESC -> id ASC', () => {
    const tiedCleaners = [
      {
        id: 'cln-B',
        nama_lengkap: 'Cleaner B',
        status_operasional: 'Aktif',
        rating_rata_rata: 4.8,
        total_ulasan: 50,
        total_pekerjaan: 60,
        pengalaman_tahun: 3,
        keahlian: ['pembersihan_rumah'],
        foto_url: ''
      },
      {
        id: 'cln-A',
        nama_lengkap: 'Cleaner A',
        status_operasional: 'Aktif',
        rating_rata_rata: 4.8,
        total_ulasan: 50,
        total_pekerjaan: 60,
        pengalaman_tahun: 3,
        keahlian: ['pembersihan_rumah'],
        foto_url: ''
      },
      {
        id: 'cln-C',
        nama_lengkap: 'Cleaner C',
        status_operasional: 'Aktif',
        rating_rata_rata: 4.8,
        total_ulasan: 50,
        total_pekerjaan: 80, // Total pekerjaan lebih tinggi
        pengalaman_tahun: 3,
        keahlian: ['pembersihan_rumah'],
        foto_url: ''
      }
    ];

    const recommendations = getRecommendations({
      cleaners: tiedCleaners,
      service: { kategori: 'rumah' },
      date: '2026-09-30',
      startTime: '09:00',
      duration: 2,
      existingOrders: []
    });

    // cln-C harus pertama karena total_pekerjaan 80 vs 60
    assert.equal(recommendations[0].cleaner.id, 'cln-C');
    // cln-A vs cln-B sama skor dan total_pekerjaan -> urut berdasarkan id ASC ('cln-A' < 'cln-B')
    assert.equal(recommendations[1].cleaner.id, 'cln-A');
    assert.equal(recommendations[2].cleaner.id, 'cln-B');
  });
});
