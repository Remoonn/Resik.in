import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import app from '../server.js';
import { db } from '../lib/database.js';

describe('Midtrans Payment API Integration Tests', () => {
  let server;
  let baseUrl;
  let testOrder;

  before(async () => {
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });

    testOrder = await db.createOrder({
      customer_id: 'usr-midtrans-test',
      service_id: 'srv-001',
      service_name: 'Pembersihan Rumah Standar',
      service_category: 'rumah',
      tanggal_layanan: '2026-10-25',
      start_time: '10:00',
      duration: 2,
      alamat_lengkap: 'Jl. Kaliurang KM 9.5 Sleman',
      patokan_lokasi: 'Dekat Indomaret',
      harga_saat_booking: 150000,
      total_biaya: 150000,
      status_pembayaran: 'Belum Bayar',
      status_pekerjaan: 'Menunggu Konfirmasi'
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('TC-MID-01: POST /api/orders/:id/payment-token menghasilkan snap token', async () => {
    const res = await fetch(`${baseUrl}/api/orders/${testOrder.id}/payment-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const json = await res.json();
    assert.strictEqual(res.status, 200);
    assert.strictEqual(json.success, true);
    assert.ok(json.data.token, 'Token harus ada');
    assert.ok(json.data.redirect_url, 'Redirect URL harus ada');
  });

  it('TC-MID-02: Webhook menolak tanda tangan palsu (403 Forbidden)', async () => {
    const res = await fetch(`${baseUrl}/api/webhooks/midtrans`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: testOrder.id,
        status_code: '200',
        gross_amount: '150000.00',
        signature_key: 'invalid-signature-hash',
        transaction_status: 'settlement'
      })
    });
    assert.strictEqual(res.status, 403);
  });

  it('TC-MID-03: Webhook valid (settlement) mengubah status_pembayaran menjadi Sudah Bayar', async () => {
    const grossAmount = '150000.00';
    const serverKey = process.env.MIDTRANS_SERVER_KEY || 'mock';
    const signature = crypto.createHash('sha512')
      .update(testOrder.id + '200' + grossAmount + serverKey)
      .digest('hex');

    const res = await fetch(`${baseUrl}/api/webhooks/midtrans`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: testOrder.id,
        status_code: '200',
        gross_amount: grossAmount,
        signature_key: signature,
        transaction_status: 'settlement',
        payment_type: 'qris',
        transaction_id: 'midtrans-txn-001'
      })
    });
    assert.strictEqual(res.status, 200);

    const updated = await db.getOrderById(testOrder.id);
    assert.strictEqual(updated.status_pembayaran, 'Sudah Bayar');
    assert.strictEqual(updated.payment_method, 'qris');
  });

  it('TC-MID-04: POST /api/orders/:id/check-payment-status menyinkronkan status secara sinkron', async () => {
    const res = await fetch(`${baseUrl}/api/orders/${testOrder.id}/check-payment-status`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const json = await res.json();
    assert.strictEqual(res.status, 200);
    assert.strictEqual(json.success, true);
    assert.strictEqual(json.data.status_pembayaran, 'Sudah Bayar');
  });
});
