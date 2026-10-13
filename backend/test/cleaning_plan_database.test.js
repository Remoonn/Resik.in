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
});
