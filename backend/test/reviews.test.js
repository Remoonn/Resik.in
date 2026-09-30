import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'http';
import app from '../server.js';
import { inMemoryStore } from '../lib/supabase.js';

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

test('POST /api/reviews — 5-Step Validation Pipeline', async (t) => {
  const custId = 'usr-cust-rev-001';
  const otherCustId = 'usr-stranger-rev-999';
  const cleanerId = 'cln-test-rev-01';
  const orderCompletedId = 'ord-test-rev-completed';
  const orderInProgressId = 'ord-test-rev-progress';

  // Seed fixtures
  inMemoryStore.cleaners = inMemoryStore.cleaners.filter(c => c.id !== cleanerId);
  inMemoryStore.cleaners.push({
    id: cleanerId,
    nama: 'Budi Santoso',
    rating_rata_rata: 4.5,
    total_ulasan: 0,
    total_pekerjaan: 10
  });

  inMemoryStore.orders = inMemoryStore.orders.filter(o => o.id !== orderCompletedId && o.id !== orderInProgressId);
  inMemoryStore.orders.push({
    id: orderCompletedId,
    customer_id: custId,
    cleaner_id: cleanerId,
    service_id: 'srv-001',
    status_pekerjaan: 'selesai'
  });

  inMemoryStore.orders.push({
    id: orderInProgressId,
    customer_id: custId,
    cleaner_id: cleanerId,
    service_id: 'srv-001',
    status_pekerjaan: 'sedang_dikerjakan'
  });

  // Bersihkan reviews fixture terkait order ini jika ada
  inMemoryStore.reviews = inMemoryStore.reviews.filter(r => r.order_id !== orderCompletedId);

  await t.test('1. Validasi rating di luar rentang (0 atau 6) ditolak dengan 400', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: custId,
        rating: 6,
        catatan_ulasan: 'Terlalu sempurna'
      })
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'INVALID_RATING');
  });

  await t.test('2. Validasi status pesanan belum selesai ditolak dengan 400', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderInProgressId,
        user_id: custId,
        rating: 5
      })
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'ORDER_NOT_COMPLETED');
  });

  await t.test('3. Validasi hak akses bukan pemilik order ditolak dengan 403', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: otherCustId,
        rating: 5
      })
    });
    assert.equal(res.status, 403);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'FORBIDDEN_NOT_ORDER_OWNER');
  });

  await t.test('4. Pengiriman ulasan valid berhasil (201 Created) dan memperbarui rating cleaner', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: custId,
        rating: 5,
        catatan_ulasan: 'Kamar sangat wangi dan bersih!'
      })
    });
    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.rating, 5);
    assert.equal(body.data.cleaner_summary.rating_rata_rata, 5.0);
    assert.equal(body.data.cleaner_summary.total_ulasan, 1);
  });

  await t.test('5. Pengiriman ulasan duplikat pada order yang sama ditolak dengan 409 Conflict', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: custId,
        rating: 4,
        catatan_ulasan: 'Coba lagi'
      })
    });
    assert.equal(res.status, 409);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'REVIEW_ALREADY_EXISTS');
  });

  await t.test('6. GET /api/reviews/order/:order_id mengembalikan ulasan yang tersimpan', async () => {
    const res = await fetch(`${baseUrl}/api/reviews/order/${orderCompletedId}`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.rating, 5);
  });

  await t.test('7. GET /api/reviews/cleaner/:cleaner_id mengembalikan daftar ulasan dengan masking nama pelanggan', async () => {
    const res = await fetch(`${baseUrl}/api/reviews/cleaner/${cleanerId}`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.total_ulasan, 1);
    assert.ok(body.data.reviews.length >= 1);
    assert.ok(body.data.reviews[0].customer_name);
  });
});
