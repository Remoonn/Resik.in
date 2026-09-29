import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';
import { inMemoryStore } from '../lib/supabase.js';

describe('Sprint 3: Order Lifecycle, Assignment & Cancellation API Tests', () => {
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
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  // Data pesanan acuan untuk tiap test
  const setupOrder = (overrides = {}) => {
    const order = {
      id: `ord-test-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      order_code: 'RSK-20260929-999',
      customer_id: 'usr-cust-001',
      service_id: 'srv-001-rumah',
      cleaner_id: null,
      tanggal_layanan: '2026-09-30',
      start_time: '09:00',
      end_time: '11:00',
      duration: 2,
      alamat_lengkap: 'Jl. Kaliurang KM 14.5 No. 20, Sleman',
      patokan_lokasi: 'Depan Warung Biru',
      luas_area: 'Tipe 36',
      catatan_khusus: null,
      harga_saat_booking: 120000,
      total_biaya: 120000,
      status_pembayaran: 'Belum Bayar',
      payment_timestamp: null,
      status_pekerjaan: 'Menunggu Konfirmasi',
      cancellation_reason: null,
      cancelled_by: null,
      cancelled_at: null,
      created_at: new Date().toISOString(),
      ...overrides
    };
    inMemoryStore.orders.push(order);
    return order;
  };

  // -------------------------------------------------------------
  // TASK 1: Transisi Status Sekuensial (PATCH /api/orders/:id/status)
  // -------------------------------------------------------------
  describe('Task 1: Status Progression (PATCH /api/orders/:id/status)', () => {
    it('TC-STS-01: Gagal konfirmasi jika status_pembayaran belum bayar (400 Bad Request)', async () => {
      const order = setupOrder({ status_pembayaran: 'Belum Bayar', status_pekerjaan: 'Menunggu Konfirmasi' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_baru: 'Dikonfirmasi', role: 'admin' })
      });

      assert.equal(res.status, 400);
      const body = await res.json();
      assert.equal(body.success, false);
      assert.equal(body.error, 'ORDER_NOT_PAID_YET');
    });

    it('TC-STS-02: Gagal transisi jika melompati status sekuensial (400 Bad Request)', async () => {
      const order = setupOrder({ status_pembayaran: 'Sudah Bayar', status_pekerjaan: 'Menunggu Konfirmasi' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_baru: 'Menuju Lokasi', role: 'cleaner' })
      });

      assert.equal(res.status, 400);
      const body = await res.json();
      assert.equal(body.success, false);
      assert.equal(body.error, 'INVALID_STATUS_TRANSITION');
    });

    it('TC-STS-03: Berhasil konfirmasi jika sudah bayar dan role admin (200 OK)', async () => {
      const order = setupOrder({ status_pembayaran: 'Sudah Bayar', status_pekerjaan: 'Menunggu Konfirmasi' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_baru: 'Dikonfirmasi', role: 'admin' })
      });

      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.data.status_pekerjaan, 'Dikonfirmasi');
    });

    it('TC-STS-04: Transisi lapangan sekuensial: Petugas Ditugaskan -> Menuju Lokasi -> Tiba di Lokasi -> Sedang Dikerjakan', async () => {
      const order = setupOrder({
        status_pembayaran: 'Sudah Bayar',
        status_pekerjaan: 'Petugas Ditugaskan',
        cleaner_id: 'cln-001'
      });

      // Step 1: Menuju Lokasi
      let res = await fetch(`${baseUrl}/api/orders/${order.id}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_baru: 'Menuju Lokasi', role: 'cleaner' })
      });
      assert.equal(res.status, 200);
      let body = await res.json();
      assert.equal(body.data.status_pekerjaan, 'Menuju Lokasi');

      // Step 2: Tiba di Lokasi
      res = await fetch(`${baseUrl}/api/orders/${order.id}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_baru: 'Tiba di Lokasi', role: 'cleaner' })
      });
      assert.equal(res.status, 200);
      body = await res.json();
      assert.equal(body.data.status_pekerjaan, 'Tiba di Lokasi');

      // Step 3: Sedang Dikerjakan (mencatat started_at)
      res = await fetch(`${baseUrl}/api/orders/${order.id}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_baru: 'Sedang Dikerjakan', role: 'cleaner' })
      });
      assert.equal(res.status, 200);
      body = await res.json();
      assert.equal(body.data.status_pekerjaan, 'Sedang Dikerjakan');
      assert.ok(body.data.started_at, 'started_at harus terisi');
    });

    it('TC-STS-05: Dilarang menyelesaikan pesanan langsung via endpoint status generic (400 Bad Request)', async () => {
      const order = setupOrder({
        status_pembayaran: 'Sudah Bayar',
        status_pekerjaan: 'Sedang Dikerjakan',
        cleaner_id: 'cln-001'
      });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_baru: 'Selesai', role: 'cleaner' })
      });

      assert.equal(res.status, 400);
      const body = await res.json();
      assert.equal(body.success, false);
      assert.equal(body.error, 'QUALITY_REPORT_REQUIRED');
    });
  });

  // -------------------------------------------------------------
  // TASK 2: Penugasan Petugas & Reassignment
  // -------------------------------------------------------------
  describe('Task 2: Assignment & Reassignment (POST /api/orders/:id/assign & reassign)', () => {
    it('TC-ASN-01: Gagal assign jika pesanan belum Dikonfirmasi (400 Bad Request)', async () => {
      const order = setupOrder({ status_pekerjaan: 'Menunggu Konfirmasi' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/assign`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cleaner_id: 'cln-001', role: 'admin' })
      });

      assert.equal(res.status, 400);
      const body = await res.json();
      assert.equal(body.error, 'ORDER_MUST_BE_CONFIRMED_BEFORE_ASSIGNMENT');
    });

    it('TC-ASN-02: Gagal assign jika jadwal petugas bentrok + buffer 30m (409 Conflict)', async () => {
      // Buat order pertama yang sudah aktif pada 09:00 - 11:00
      setupOrder({
        cleaner_id: 'cln-001',
        tanggal_layanan: '2026-09-30',
        start_time: '09:00',
        end_time: '11:00',
        status_pekerjaan: 'Petugas Ditugaskan'
      });

      // Order kedua ingin menugaskan cleaner yang sama pada 11:15 (dalam buffer 30m setelah 11:00)
      const order2 = setupOrder({
        cleaner_id: null,
        tanggal_layanan: '2026-09-30',
        start_time: '11:15',
        end_time: '13:15',
        status_pekerjaan: 'Dikonfirmasi',
        status_pembayaran: 'Sudah Bayar'
      });

      const res = await fetch(`${baseUrl}/api/orders/${order2.id}/assign`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cleaner_id: 'cln-001', role: 'admin' })
      });

      assert.equal(res.status, 409);
      const body = await res.json();
      assert.equal(body.error, 'SCHEDULE_CONFLICT_DETECTED');
    });

    it('TC-ASN-03: Berhasil assign jika bebas bentrok jadwal (200 OK)', async () => {
      const order = setupOrder({
        cleaner_id: null,
        tanggal_layanan: '2026-09-30',
        start_time: '14:00',
        end_time: '16:00',
        status_pekerjaan: 'Dikonfirmasi',
        status_pembayaran: 'Sudah Bayar'
      });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/assign`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cleaner_id: 'cln-001', role: 'admin' })
      });

      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.data.status_pekerjaan, 'Petugas Ditugaskan');
      assert.equal(body.data.cleaner_id, 'cln-001');
    });

    it('TC-ASN-04: Berhasil reassign petugas dan mencatat audit log (200 OK)', async () => {
      const order = setupOrder({
        cleaner_id: 'cln-001',
        tanggal_layanan: '2026-09-30',
        start_time: '14:00',
        end_time: '16:00',
        status_pekerjaan: 'Petugas Ditugaskan',
        status_pembayaran: 'Sudah Bayar'
      });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/reassign`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          new_cleaner_id: 'cln-002',
          alasan: 'Petugas pertama berhalangan hadir darurat',
          role: 'admin'
        })
      });

      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.data.cleaner_id, 'cln-002');

      // Verifikasi catatan di status_logs
      const log = inMemoryStore.status_logs.find(l => l.order_id === order.id && l.catatan.includes('REASSIGN_CLEANER'));
      assert.ok(log, 'Audit log reassign harus tersimpan di status_logs');
      assert.ok(log.catatan.includes('cln-001 ke cln-002'));
    });
  });

  // -------------------------------------------------------------
  // TASK 3: Pembatalan Pesanan Berbasis Peran
  // -------------------------------------------------------------
  describe('Task 3: Cancellation (POST /api/orders/:id/cancel)', () => {
    it('TC-CNC-01: Gagal batalkan jika alasan kurang dari 5 karakter (400 Bad Request)', async () => {
      const order = setupOrder({ status_pekerjaan: 'Menunggu Konfirmasi' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/cancel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cancellation_reason: 'Gak', role: 'customer' })
      });

      assert.equal(res.status, 400);
      const body = await res.json();
      assert.equal(body.error, 'INVALID_CANCELLATION_REASON');
    });

    it('TC-CNC-02: Pelanggan dilarang membatalkan jika pesanan sudah masuk tahap lapangan (403 Forbidden)', async () => {
      const order = setupOrder({ status_pekerjaan: 'Menuju Lokasi', cleaner_id: 'cln-001' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/cancel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          cancellation_reason: 'Saya mau pergi mendadak',
          role: 'customer'
        })
      });

      assert.equal(res.status, 403);
      const body = await res.json();
      assert.equal(body.error, 'CUSTOMER_CANNOT_CANCEL_DISPATCHED_ORDER');
    });

    it('TC-CNC-03: Pelanggan diizinkan membatalkan saat Dikonfirmasi / Petugas Ditugaskan (200 OK)', async () => {
      const order = setupOrder({ status_pekerjaan: 'Petugas Ditugaskan', cleaner_id: 'cln-001' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/cancel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          cancellation_reason: 'Perubahan jadwal mendadak dari keluarga',
          role: 'customer'
        })
      });

      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.data.status_pekerjaan, 'Dibatalkan');
      assert.equal(body.data.cancelled_by, 'customer');
    });

    it('TC-CNC-04: Admin diizinkan membatalkan darurat saat Sedang Dikerjakan (200 OK)', async () => {
      const order = setupOrder({ status_pekerjaan: 'Sedang Dikerjakan', cleaner_id: 'cln-001' });

      const res = await fetch(`${baseUrl}/api/orders/${order.id}/cancel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          cancellation_reason: 'Terjadi pemadaman listrik total di area pelanggan',
          role: 'admin'
        })
      });

      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.data.status_pekerjaan, 'Dibatalkan');
      assert.equal(body.data.cancelled_by, 'admin');
    });
  });
});
