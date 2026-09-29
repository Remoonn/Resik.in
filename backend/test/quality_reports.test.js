// backend/test/quality_reports.test.js
import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';
import { inMemoryStore } from '../lib/supabase.js';
import { CHECKLIST_TEMPLATES } from '../lib/checklist-templates.js';

describe('Quality Report Checklist Templates', () => {
  test('harus menyediakan template lengkap untuk 4 kategori layanan', () => {
    assert.ok(CHECKLIST_TEMPLATES.rumah);
    assert.strictEqual(CHECKLIST_TEMPLATES.rumah.length, 5);
    assert.ok(CHECKLIST_TEMPLATES.kos);
    assert.strictEqual(CHECKLIST_TEMPLATES.kos.length, 3);
    assert.ok(CHECKLIST_TEMPLATES.kantor);
    assert.strictEqual(CHECKLIST_TEMPLATES.kantor.length, 4);
    assert.ok(CHECKLIST_TEMPLATES.renovasi);
    assert.strictEqual(CHECKLIST_TEMPLATES.renovasi.length, 4);
  });
});

describe('POST /api/quality-reports — 9-Stage Validation Pipeline', () => {
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

  const setupOrderInProgress = (overrides = {}) => {
    const startedAt = new Date(Date.now() - 3600000).toISOString(); // 1 jam lalu
    const order = {
      id: `ord-qr-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      order_code: 'RSK-20260929-QR1',
      customer_id: 'usr-cust-001',
      service_id: 'srv-001-rumah',
      cleaner_id: 'cln-001',
      tanggal_layanan: '2026-09-29',
      start_time: '09:00',
      end_time: '11:00',
      duration: 2,
      alamat_lengkap: 'Jl. Kaliurang KM 14.5 No. 20',
      patokan_lokasi: 'Depan Warung Biru',
      luas_area: 'Tipe 36',
      catatan_khusus: null,
      harga_saat_booking: 120000,
      total_biaya: 120000,
      status_pembayaran: 'Sudah Bayar',
      payment_timestamp: new Date().toISOString(),
      status_pekerjaan: 'Sedang Dikerjakan',
      started_at: startedAt,
      created_at: new Date(Date.now() - 7200000).toISOString(),
      ...overrides
    };
    inMemoryStore.orders.push(order);
    return order;
  };

  test('POST /api/quality-reports sukses menyimpan laporan, mengubah status ke Selesai, dan memulihkan cleaner', async () => {
    const order = setupOrderInProgress();
    const cleaner = inMemoryStore.cleaners.find(c => c.id === 'cln-001');
    const initialJobs = cleaner ? cleaner.total_pekerjaan : 0;
    if (cleaner) cleaner.status_operasional = 'Sedang Bekerja';

    const completedAt = new Date(Date.now() - 60000).toISOString(); // 1 menit lalu

    const payload = {
      order_id: order.id,
      checklist_area: [
        { area: 'Ruang Tamu', completed: true },
        { area: 'Kamar Tidur', completed: true },
        { area: 'Dapur', completed: true },
        { area: 'Kamar Mandi', completed: true },
        { area: 'Area Tambahan Sesuai Paket', completed: true }
      ],
      foto_before_path: `orders/${order.id}/before_123.webp`,
      foto_after_path: `orders/${order.id}/after_456.webp`,
      catatan_petugas: 'Semua ruangan bersih tuntas berkilau.',
      completed_at: completedAt,
      role: 'cleaner',
      cleaner_id: 'cln-001'
    };

    const res = await fetch(`${baseUrl}/api/quality-reports`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const body = await res.json();
    assert.strictEqual(res.status, 201);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.status_pekerjaan, 'Selesai');

    // Verifikasi mutasi order
    const updatedOrder = inMemoryStore.orders.find(o => o.id === order.id);
    assert.strictEqual(updatedOrder.status_pekerjaan, 'Selesai');

    // Verifikasi cleaner metrics
    const updatedCleaner = inMemoryStore.cleaners.find(c => c.id === 'cln-001');
    assert.strictEqual(updatedCleaner.status_operasional, 'Aktif');
    assert.strictEqual(updatedCleaner.total_pekerjaan, initialJobs + 1);

    // Verifikasi tabel quality_reports
    const savedReport = inMemoryStore.quality_reports.find(r => r.order_id === order.id);
    assert.ok(savedReport);
    assert.strictEqual(savedReport.foto_before_url, payload.foto_before_path);
    assert.strictEqual(savedReport.checklist_area.length, 5);
  });

  test('POST /api/quality-reports menolak jika checklist tidak lengkap atau ada yang completed: false', async () => {
    const order = setupOrderInProgress();

    const payload = {
      order_id: order.id,
      checklist_area: [
        { area: 'Ruang Tamu', completed: true },
        { area: 'Kamar Tidur', completed: false }, // Belum selesai
        { area: 'Dapur', completed: true },
        { area: 'Kamar Mandi', completed: true },
        { area: 'Area Tambahan Sesuai Paket', completed: true }
      ],
      foto_before_path: `orders/${order.id}/before_123.webp`,
      foto_after_path: `orders/${order.id}/after_456.webp`,
      completed_at: new Date().toISOString(),
      role: 'cleaner',
      cleaner_id: 'cln-001'
    };

    const res = await fetch(`${baseUrl}/api/quality-reports`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const body = await res.json();
    assert.strictEqual(res.status, 400);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error, 'CHECKLIST_AREAS_INCOMPLETE');
  });

  test('POST /api/quality-reports menolak jika completed_at mendahului started_at atau di masa depan', async () => {
    const order = setupOrderInProgress({ started_at: '2026-09-29T10:00:00.000Z' });

    // Skenario A: completed_at lebih awal dari started_at
    const payloadEarly = {
      order_id: order.id,
      checklist_area: CHECKLIST_TEMPLATES.rumah.map(a => ({ area: a, completed: true })),
      foto_before_path: `orders/${order.id}/before_123.webp`,
      foto_after_path: `orders/${order.id}/after_456.webp`,
      completed_at: '2026-09-29T09:30:00.000Z', // Lebih awal dari 10:00
      role: 'cleaner',
      cleaner_id: 'cln-001'
    };

    const res = await fetch(`${baseUrl}/api/quality-reports`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payloadEarly)
    });

    const body = await res.json();
    assert.strictEqual(res.status, 400);
    assert.strictEqual(body.error, 'INVALID_TIMESTAMPS');
  });

  test('POST /api/quality-reports menolak jika status pesanan bukan Sedang Dikerjakan', async () => {
    const order = setupOrderInProgress({ status_pekerjaan: 'Dikonfirmasi' });

    const payload = {
      order_id: order.id,
      checklist_area: CHECKLIST_TEMPLATES.rumah.map(a => ({ area: a, completed: true })),
      foto_before_path: `orders/${order.id}/before_123.webp`,
      foto_after_path: `orders/${order.id}/after_456.webp`,
      completed_at: new Date().toISOString(),
      role: 'cleaner',
      cleaner_id: 'cln-001'
    };

    const res = await fetch(`${baseUrl}/api/quality-reports`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const body = await res.json();
    assert.strictEqual(res.status, 400);
    assert.strictEqual(body.error, 'ORDER_NOT_IN_PROGRESS');
  });

  test('POST /api/quality-reports menolak jika path foto tidak berawalan orders/{order_id}/', async () => {
    const order = setupOrderInProgress();

    const payload = {
      order_id: order.id,
      checklist_area: CHECKLIST_TEMPLATES.rumah.map(a => ({ area: a, completed: true })),
      foto_before_path: 'arbitrary_folder/before.webp', // Salah
      foto_after_path: `orders/${order.id}/after.webp`,
      completed_at: new Date().toISOString(),
      role: 'cleaner',
      cleaner_id: 'cln-001'
    };

    const res = await fetch(`${baseUrl}/api/quality-reports`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const body = await res.json();
    assert.strictEqual(res.status, 400);
    assert.strictEqual(body.error, 'INVALID_STORAGE_PATH');
  });

  test('POST /api/quality-reports sukses memproses pesanan kategori kos dengan 3 checklist area', async () => {
    const order = setupOrderInProgress({
      service_id: 'uuid-supabase-kos-1234',
      service_kategori: 'kos'
    });

    const payload = {
      order_id: order.id,
      service_category: 'kos',
      checklist_area: [
        { area: 'Kamar Tidur / Utama', completed: true },
        { area: 'Kamar Mandi', completed: true },
        { area: 'Area yang Termasuk Paket', completed: true }
      ],
      foto_before_path: `orders/${order.id}/before_kos.webp`,
      foto_after_path: `orders/${order.id}/after_kos.webp`,
      catatan_petugas: 'Kamar kos rapi dan wangi.',
      completed_at: new Date(Date.now() - 5000).toISOString(),
      role: 'cleaner',
      cleaner_id: 'cln-001'
    };

    const res = await fetch(`${baseUrl}/api/quality-reports`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const body = await res.json();
    assert.strictEqual(res.status, 201);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.status_pekerjaan, 'Selesai');
  });

  describe('GET /api/quality-reports/:order_id — Signed URL & RBAC', () => {
    test('Pelanggan pemilik order dan Petugas berhasil mengambil laporan dengan signed URLs', async () => {
      const order = setupOrderInProgress();
      const payload = {
        order_id: order.id,
        checklist_area: CHECKLIST_TEMPLATES.rumah.map(a => ({ area: a, completed: true })),
        foto_before_path: `orders/${order.id}/before_123.webp`,
        foto_after_path: `orders/${order.id}/after_456.webp`,
        catatan_petugas: 'Selesai rapi',
        completed_at: new Date(Date.now() - 1000).toISOString(),
        role: 'cleaner',
        cleaner_id: 'cln-001'
      };

      await fetch(`${baseUrl}/api/quality-reports`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      // Customer pemilik order mengambil laporan
      const res = await fetch(`${baseUrl}/api/quality-reports/${order.id}?user_id=${order.customer_id}&role=customer`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.data.order_id, order.id);
      assert.ok(body.data.foto_before_signed_url);
      assert.ok(body.data.foto_after_signed_url);
      assert.strictEqual(body.data.signed_url_expires_in, 1800);
      assert.strictEqual(body.data.is_locked, true);
    });

    test('Pengguna lain (bukan customer, bukan cleaner, bukan admin) ditolak dengan 403 Forbidden', async () => {
      const order = setupOrderInProgress();
      const payload = {
        order_id: order.id,
        checklist_area: CHECKLIST_TEMPLATES.rumah.map(a => ({ area: a, completed: true })),
        foto_before_path: `orders/${order.id}/before_123.webp`,
        foto_after_path: `orders/${order.id}/after_456.webp`,
        completed_at: new Date(Date.now() - 1000).toISOString(),
        role: 'cleaner',
        cleaner_id: 'cln-001'
      };

      await fetch(`${baseUrl}/api/quality-reports`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      // User lain yang tidak berhak
      const res = await fetch(`${baseUrl}/api/quality-reports/${order.id}?user_id=usr-other-stranger&role=customer`);
      const body = await res.json();

      assert.strictEqual(res.status, 403);
      assert.strictEqual(body.success, false);
      assert.strictEqual(body.error, 'FORBIDDEN_REPORT_ACCESS');
    });

    test('Mengembalikan 404 jika order belum memiliki laporan mutu', async () => {
      const order = setupOrderInProgress();

      const res = await fetch(`${baseUrl}/api/quality-reports/${order.id}?user_id=${order.customer_id}&role=customer`);
      const body = await res.json();

      assert.strictEqual(res.status, 404);
      assert.strictEqual(body.error, 'REPORT_NOT_FOUND');
    });

    test('Menyimpan dan menyajikan data biner foto via GET /api/quality-reports/:order_id/photo/:type', async () => {
      const order = setupOrderInProgress();
      const dummyPhotoBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkWPifAQAE+wH9Z5g6WAAAAABJRU5ErkJggg==';

      const payload = {
        order_id: order.id,
        checklist_area: CHECKLIST_TEMPLATES.rumah.map(a => ({ area: a, completed: true })),
        foto_before_path: `orders/${order.id}/before_photo.webp`,
        foto_after_path: `orders/${order.id}/after_photo.webp`,
        foto_before_data: `data:image/png;base64,${dummyPhotoBase64}`,
        foto_after_data: dummyPhotoBase64,
        completed_at: new Date(Date.now() - 1000).toISOString(),
        role: 'cleaner',
        cleaner_id: 'cln-001'
      };

      const submitRes = await fetch(`${baseUrl}/api/quality-reports`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      assert.strictEqual(submitRes.status, 201);

      // Ambil foto before via streaming endpoint
      const photoBeforeRes = await fetch(`${baseUrl}/api/quality-reports/${order.id}/photo/before`);
      assert.strictEqual(photoBeforeRes.status, 200);
      assert.strictEqual(photoBeforeRes.headers.get('content-type'), 'image/png');
      const beforeBuffer = await photoBeforeRes.arrayBuffer();
      assert.ok(beforeBuffer.byteLength > 0);

      // Ambil foto after via streaming endpoint
      const photoAfterRes = await fetch(`${baseUrl}/api/quality-reports/${order.id}/photo/after`);
      assert.strictEqual(photoAfterRes.status, 200);
      assert.strictEqual(photoAfterRes.headers.get('content-type'), 'image/jpeg');

      // Ambil foto pesanan yang belum diupload foto (fallback PNG)
      const emptyOrder = setupOrderInProgress();
      const fallbackRes = await fetch(`${baseUrl}/api/quality-reports/${emptyOrder.id}/photo/before`);
      assert.strictEqual(fallbackRes.status, 200);
      assert.strictEqual(fallbackRes.headers.get('content-type'), 'image/png');
    });
  });
});

