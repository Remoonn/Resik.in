import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'http';
import app from '../server.js';

let server;
let baseUrl;

test.before(async () => {
  await new Promise((resolve) => {
    server = http.createServer(app);
    server.listen(0, () => {
      const port = server.address().port;
      baseUrl = `http://127.0.0.1:${port}`;
      resolve();
    });
  });
});

test.after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('Cleaning Plans REST API Integration Tests', async (t) => {
  let createdPlanId = '';

  await t.test('1. POST /api/cleaning-plans: berhasil membuat plan dan order sesi perdana', async () => {
    const res = await fetch(`${baseUrl}/api/cleaning-plans`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        customerId: 'usr-cust-api-01',
        planName: 'Rutin Kos Mahasiswa',
        serviceCategory: 'kos',
        serviceId: 'srv-002',
        frequency: 'mingguan',
        dayOfWeek: 1,
        dayName: 'Senin',
        startTime: '09:00',
        duration: 2,
        pricePerSession: 75000,
        address: 'Jl. Kaliurang KM 14.5 Gang Melati No. 8',
        landmark: 'Dekat warung madura',
        notes: 'Fokus bersihkan kamar mandi',
        preferredCleanerId: 'cln-001'
      })
    });

    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.data.plan.id);
    assert.equal(body.data.plan.planName, 'Rutin Kos Mahasiswa');
    assert.ok(body.data.initialOrder.id);
    assert.equal(body.data.initialOrder.session_number, 1);
    assert.equal(body.data.initialOrder.status_pekerjaan, 'Menunggu Konfirmasi');

    createdPlanId = body.data.plan.id;
  });

  await t.test('2. POST /api/cleaning-plans: validasi gagal jika jam di luar 08:00-17:00 atau alamat terlalu pendek', async () => {
    const res = await fetch(`${baseUrl}/api/cleaning-plans`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        customerId: 'usr-cust-api-01',
        planName: 'Tes Invalid',
        serviceCategory: 'kos',
        frequency: 'mingguan',
        dayOfWeek: 1,
        dayName: 'Senin',
        startTime: '20:00', // Di luar jam operasional (08:00 - 17:59)
        duration: 2,
        address: 'Pendek' // Kurang dari 10 karakter
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.ok(body.message);
  });

  await t.test('3. GET /api/cleaning-plans: mengambil daftar paket pelanggan ter-hidrasi', async () => {
    const res = await fetch(`${baseUrl}/api/cleaning-plans?customer_id=usr-cust-api-01`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.ok(body.data.length >= 1);
    const plan = body.data.find(p => p.id === createdPlanId);
    assert.ok(plan, 'Plan yang baru dibuat harus ditemukan di daftar');
  });

  await t.test('4. GET /api/cleaning-plans/:id: mengambil rincian detail paket beserta riwayat pesanan', async () => {
    const res = await fetch(`${baseUrl}/api/cleaning-plans/${createdPlanId}`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.plan.id, createdPlanId);
    assert.ok(Array.isArray(body.data.orders));
    assert.ok(body.data.orders.length >= 1);
  });

  await t.test('5. PATCH /api/cleaning-plans/:id/status: jeda dan aktifkan kembali paket', async () => {
    const pauseRes = await fetch(`${baseUrl}/api/cleaning-plans/${createdPlanId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'Dijeda' })
    });
    assert.equal(pauseRes.status, 200);
    const pauseBody = await pauseRes.json();
    assert.equal(pauseBody.data.status, 'Dijeda');

    const resumeRes = await fetch(`${baseUrl}/api/cleaning-plans/${createdPlanId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'Aktif' })
    });
    assert.equal(resumeRes.status, 200);
    const resumeBody = await resumeRes.json();
    assert.equal(resumeBody.data.status, 'Aktif');
  });

  await t.test('6. POST /api/cleaning-plans/:id/generate-next-session: trigger manual sesi berikutnya untuk sidang', async () => {
    const res = await fetch(`${baseUrl}/api/cleaning-plans/${createdPlanId}/generate-next-session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.data.order.id);
    assert.equal(body.data.order.session_number, 2);
    assert.ok(body.data.plan);
  });
});
