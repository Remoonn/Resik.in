import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateNextSessionDate, generateNextSessionOrder } from '../lib/cleaning-plan-engine.js';

test('Cleaning Plan Engine Unit Tests', async (t) => {
  await t.test('1. calculateNextSessionDate: menghitung target hari mingguan (+7 hari atau hari terdekat)', () => {
    // 2026-10-13 adalah Selasa (dayOfWeek: 2)
    const baseDate = new Date('2026-10-13T10:00:00.000Z');
    
    // Target Senin (dayOfWeek: 1) berikutnya: 2026-10-19
    const nextMonday = calculateNextSessionDate({
      dayOfWeek: 1,
      frequency: 'mingguan',
      fromDate: baseDate
    });
    assert.equal(nextMonday, '2026-10-19');

    // Target Selasa minggu depan jika jam sudah lewat: 2026-10-20
    const nextTuesday = calculateNextSessionDate({
      dayOfWeek: 2,
      frequency: 'mingguan',
      fromDate: baseDate,
      startTime: '08:00', // Sudah lewat dari 10:00
      currentTimeStr: '10:00'
    });
    assert.equal(nextTuesday, '2026-10-20');
  });

  await t.test('2. calculateNextSessionDate: menghitung target dua mingguan (+14 hari)', () => {
    const baseDate = new Date('2026-10-19T09:00:00.000Z');
    const biweekly = calculateNextSessionDate({
      dayOfWeek: 1,
      frequency: 'dua_mingguan',
      fromDate: baseDate,
      skipFirstInterval: true
    });
    assert.equal(biweekly, '2026-11-02');
  });

  await t.test('3. generateNextSessionOrder: membentuk order dengan session_number dan cleaning_plan_id', () => {
    const mockPlan = {
      id: 'plan-test-001',
      customerId: 'usr-cust-001',
      planName: 'Kos Rutin',
      serviceCategory: 'kos',
      serviceId: 'srv-002',
      frequency: 'mingguan',
      dayOfWeek: 1,
      dayName: 'Senin',
      startTime: '09:00',
      duration: 2,
      pricePerSession: 100000,
      address: 'Jl. Kaliurang KM 14.5 No. 4',
      landmark: 'Pagar hitam',
      notes: 'Bersih kamar mandi',
      preferredCleanerId: 'cln-001',
      status: 'Aktif',
      nextSessionDate: '2026-10-19',
      totalSessionsCompleted: 2
    };

    const order = generateNextSessionOrder({
      plan: mockPlan,
      existingOrders: []
    });

    assert.ok(order.id);
    assert.equal(order.customer_id, 'usr-cust-001');
    assert.equal(order.cleaner_id, 'cln-001');
    assert.equal(order.cleaning_plan_id, 'plan-test-001');
    assert.equal(order.session_number, 3);
    assert.equal(order.status, 'Menunggu Konfirmasi');
    assert.equal(order.status_pembayaran, 'Belum Bayar');
    assert.ok(order.start_time.startsWith('2026-10-19'));
  });

  await t.test('4. conflict fallback: alihkan cleaner_id ke null jika petugas favorit bentrok', () => {
    const mockPlan = {
      id: 'plan-test-001',
      customerId: 'usr-cust-001',
      planName: 'Kos Rutin',
      serviceCategory: 'kos',
      serviceId: 'srv-002',
      frequency: 'mingguan',
      dayOfWeek: 1,
      startTime: '09:00',
      duration: 2,
      pricePerSession: 100000,
      address: 'Jl. Kaliurang',
      preferredCleanerId: 'cln-001',
      status: 'Aktif',
      nextSessionDate: '2026-10-19',
      totalSessionsCompleted: 0
    };

    // Buat order bentrok untuk cln-001 di 2026-10-19 jam 09:00
    const conflictingOrder = {
      id: 'ord-conflict',
      cleaner_id: 'cln-001',
      start_time: '2026-10-19T09:00:00.000Z',
      duration: 2,
      status: 'Dikonfirmasi'
    };

    const order = generateNextSessionOrder({
      plan: mockPlan,
      existingOrders: [conflictingOrder]
    });

    assert.equal(order.cleaner_id, null, 'cleaner_id harus null saat bentrok');
    assert.ok(order.notes.includes('[Jadwal Bentrok]'), 'Notes harus memuat catatan bentrok jadwal');
  });

  await t.test('5. idempotency: menolak jika pesanan untuk tanggal yang sama sudah dibuat', () => {
    const mockPlan = {
      id: 'plan-test-001',
      nextSessionDate: '2026-10-19'
    };
    const existingOrder = {
      id: 'ord-existing',
      cleaning_plan_id: 'plan-test-001',
      start_time: '2026-10-19T09:00:00.000Z'
    };

    assert.throws(() => {
      generateNextSessionOrder({
        plan: mockPlan,
        existingOrders: [existingOrder]
      });
    }, /sudah dibuat/);
  });
});
