import test from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../lib/database.js';

test('Cleaning Plan Database Store Tests', async (t) => {
  let createdPlanId;

  await t.test('1. Menyimpan dan mengambil cleaning plan baru', async () => {
    const plan = await db.createCleaningPlan({
      customerId: 'usr-cust-test-01',
      planName: 'Langganan Bersih Kos',
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
      notes: 'Kamar mandi & balkon',
      preferredCleanerId: 'cln-001',
      nextSessionDate: '2026-10-19'
    });

    assert.ok(plan.id, 'Plan harus memiliki ID yang ter-generate');
    assert.equal(plan.planName, 'Langganan Bersih Kos');
    assert.equal(plan.status, 'Aktif');
    assert.equal(plan.totalSessionsCompleted, 0);

    createdPlanId = plan.id;
    const fetched = await db.getCleaningPlanById(plan.id);
    assert.ok(fetched, 'Plan harus dapat diambil kembali dari database');
    assert.equal(fetched.id, plan.id);
    assert.equal(fetched.dayOfWeek, 1);
  });

  await t.test('2. Mengambil daftar plan berdasarkan customerId', async () => {
    const customerPlans = await db.getCleaningPlansByCustomerId('usr-cust-test-01');
    assert.ok(Array.isArray(customerPlans), 'Hasil harus berupa array');
    assert.ok(customerPlans.length >= 1, 'Harus memiliki minimal 1 plan');
    assert.equal(customerPlans[0].customerId, 'usr-cust-test-01');
  });

  await t.test('3. Memperbarui status cleaning plan', async () => {
    const paused = await db.updateCleaningPlanStatus(createdPlanId, 'Dijeda');
    assert.equal(paused.status, 'Dijeda');

    const active = await db.updateCleaningPlanStatus(createdPlanId, 'Aktif');
    assert.equal(active.status, 'Aktif');
  });

  await t.test('4. Memperbarui nextSessionDate dan totalSessionsCompleted', async () => {
    const updated = await db.updateCleaningPlanNextSession(createdPlanId, '2026-10-26', true);
    assert.equal(updated.nextSessionDate, '2026-10-26');
    assert.equal(updated.totalSessionsCompleted, 1);
  });

  await t.test('5. incrementCleaningPlanSessionsCompleted menambah totalSessionsCompleted secara independen', async () => {
    const incremented = await db.incrementCleaningPlanSessionsCompleted(createdPlanId);
    assert.ok(incremented);
    assert.equal(incremented.totalSessionsCompleted, 2);
  });

  await t.test('6. saveQualityReport secara otomatis meng-increment totalSessionsCompleted saat order selesai', async () => {
    // 1. Buat order terkait cleaning plan
    const sessionOrder = await db.createOrder({
      id: 'ord-plan-session-test-01',
      customer_id: 'usr-cust-test-01',
      cleaner_id: 'cln-001',
      service_id: 'srv-002',
      service_category: 'kos',
      start_time: '2026-10-19T09:00:00.000Z',
      duration: 2,
      total_biaya: 100000,
      alamat_lengkap: 'Jl. Kaliurang KM 14.5 No. 4',
      status_pekerjaan: 'Sedang Dikerjakan',
      cleaning_plan_id: createdPlanId,
      session_number: 1
    });

    const beforePlan = await db.getCleaningPlanById(createdPlanId);
    const prevCompleted = beforePlan.totalSessionsCompleted;

    // 2. Submit quality report untuk menyelesaikan order
    await db.saveQualityReport({
      order_id: sessionOrder.id,
      cleaner_id: 'cln-001',
      checklist_area: [{ area: 'Kamar Kos', completed: true }],
      foto_before_url: `orders/${sessionOrder.id}/before.jpg`,
      foto_after_url: `orders/${sessionOrder.id}/after.jpg`,
      catatan_petugas: 'Selesai bersih kos',
      started_at: new Date(Date.now() - 3600000).toISOString(),
      completed_at: new Date().toISOString()
    });

    // 3. Verifikasi cleaning plan totalSessionsCompleted bertambah 1
    const afterPlan = await db.getCleaningPlanById(createdPlanId);
    assert.equal(afterPlan.totalSessionsCompleted, prevCompleted + 1);
  });
});
