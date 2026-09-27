import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';
import { inMemoryStore } from '../lib/supabase.js';

describe('Sprint 1: Core Booking & Payment API Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });

    // Ambil service_id yang aktif secara dinamis (live Supabase atau fallback)
    const sRes = await fetch(`${baseUrl}/api/services`);
    const sBody = await sRes.json();
    const serviceRumah = sBody.data.find(s => s.kategori === 'rumah');
    if (serviceRumah) {
      validOrderPayload.service_id = serviceRumah.id;
    }
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  const validOrderPayload = {
    service_id: 'srv-001-rumah',
    alamat_lengkap: 'Jl. Kaliurang KM 14.5 No. 20, Sleman, Yogyakarta',
    patokan_lokasi: 'Depan Warung Madura cat biru',
    luas_area: 'Tipe 36',
    catatan_khusus: 'Tolong bersihkan debu di plafon ruang tamu',
    tanggal_layanan: '2026-09-30',
    start_time: '09:00',
    duration: 2
  };

  it('TC-ORD-01: Gagal membuat pesanan jika field wajib kosong (400 Bad Request)', async () => {
    const invalidPayload = { ...validOrderPayload };
    delete invalidPayload.alamat_lengkap;

    const res = await fetch(`${baseUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(invalidPayload)
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.ok(body.message.includes('alamat_lengkap') || body.error === 'MISSING_MANDATORY_FIELDS');
  });

  it('TC-ORD-02: Gagal jika alamat < 10 karakter atau patokan < 3 karakter (400 Bad Request)', async () => {
    const shortAddressPayload = {
      ...validOrderPayload,
      alamat_lengkap: 'Jl. Pendek',
      patokan_lokasi: 'Ok'
    };

    const res = await fetch(`${baseUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(shortAddressPayload)
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
  });

  it('TC-ORD-03: Gagal jika start_time di luar jam operasional 08:00 - 17:00 (400 Bad Request)', async () => {
    const earlyPayload = { ...validOrderPayload, start_time: '06:30' };
    const latePayload = { ...validOrderPayload, start_time: '18:00' };

    const resEarly = await fetch(`${baseUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(earlyPayload)
    });
    assert.equal(resEarly.status, 400);

    const resLate = await fetch(`${baseUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(latePayload)
    });
    assert.equal(resLate.status, 400);
  });

  it('TC-ORD-04: Gagal jika klien mencoba mengirim status_pembayaran (400 Bad Request)', async () => {
    const maliciousPayload = {
      ...validOrderPayload,
      status_pembayaran: 'Sudah Bayar'
    };

    const res = await fetch(`${baseUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(maliciousPayload)
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'FORBIDDEN_PAYMENT_STATUS_INJECTION');
  });

  it('TC-PRC-01 & TC-ORD-05: Berhasil membuat pesanan dengan snapshot tarif flat deterministik (201 Created)', async () => {
    const res = await fetch(`${baseUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validOrderPayload)
    });

    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.data.id, 'Order ID harus terbuat');
    assert.ok(body.data.order_code.startsWith('RSK-'), 'Order code harus berformat RSK-YYYYMMDD-XXX');
    
    // Validasi snapshot tarif flat
    assert.equal(body.data.harga_saat_booking, 120000.00);
    assert.equal(body.data.total_biaya, 120000.00);
    
    // Validasi initial state
    assert.equal(body.data.status_pembayaran, 'Belum Bayar');
    assert.equal(body.data.status_pekerjaan, 'Menunggu Konfirmasi');
    assert.equal(body.data.payment_timestamp, null);

    // Simpan orderId untuk test berikutnya
    validOrderPayload.createdOrderId = body.data.id;
  });

  it('TC-PAY-01: Gagal membayar pesanan yang tidak ditemukan (404 Not Found)', async () => {
    const res = await fetch(`${baseUrl}/api/orders/non-existent-order-id/pay`, {
      method: 'POST'
    });

    assert.equal(res.status, 404);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'ORDER_NOT_FOUND');
  });

  it('TC-PAY-02: Berhasil simulasi pembayaran server-authoritative (200 OK)', async () => {
    const orderId = validOrderPayload.createdOrderId;
    assert.ok(orderId, 'Order ID dari test pembuatan pesanan harus tersedia');

    const res = await fetch(`${baseUrl}/api/orders/${orderId}/pay`, {
      method: 'POST'
    });

    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.id, orderId);
    assert.equal(body.data.status_pembayaran, 'Sudah Bayar');
    assert.ok(body.data.payment_timestamp, 'payment_timestamp harus dicatat oleh server');
  });

  it('TC-PAY-03: Gagal membayar ulang pesanan yang sudah berstatus Sudah Bayar (400 Bad Request)', async () => {
    const orderId = validOrderPayload.createdOrderId;

    const res = await fetch(`${baseUrl}/api/orders/${orderId}/pay`, {
      method: 'POST'
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'ORDER_ALREADY_PAID');
  });

  it('TC-ORD-06: Mengambil detail lengkap pesanan via GET /api/orders/:id (200 OK)', async () => {
    const orderId = validOrderPayload.createdOrderId;

    const res = await fetch(`${baseUrl}/api/orders/${orderId}`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.id, orderId);
    assert.equal(body.data.service.nama_layanan, 'Pembersihan Rumah');
    assert.equal(body.data.status_pembayaran, 'Sudah Bayar');
    assert.equal(body.data.status_pekerjaan, 'Menunggu Konfirmasi');
    assert.equal(body.data.end_time, '11:00'); // 09:00 + 2 jam
  });
});
