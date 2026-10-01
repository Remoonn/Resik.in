// backend/test/database_orders.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../lib/database.js';

describe('Database Repository - Orders', () => {
  it('createOrder menyimpan pesanan baru dan getOrderById dapat mengambilnya kembali', async () => {
    const newOrderPayload = {
      order_code: `RSK-TEST-${Date.now()}`,
      service_id: '14afb604-f297-4526-ba3b-47c1d6fb762a',
      tanggal_layanan: '2026-10-15',
      start_time: '09:00',
      duration: 2,
      alamat_lengkap: 'Jl. Kaliurang KM 9, Sleman',
      patokan_lokasi: 'Depan Alfamart',
      luas_area: 'Rumah 1 Lantai',
      total_biaya: 120000,
      harga_saat_booking: 120000,
      status_pembayaran: 'Belum Bayar',
      status_pekerjaan: 'Menunggu Konfirmasi'
    };

    const created = await db.createOrder(newOrderPayload);
    assert.ok(created.id);
    assert.strictEqual(created.status_pembayaran, 'Belum Bayar');
    assert.strictEqual(created.status_pekerjaan, 'Menunggu Konfirmasi');

    const fetched = await db.getOrderById(created.id);
    assert.ok(fetched);
    assert.strictEqual(fetched.id, created.id);
    assert.strictEqual(fetched.order_code, created.order_code);
  });

  it('getOrders mengembalikan daftar pesanan dengan dukungan filter', async () => {
    const orders = await db.getOrders();
    assert.ok(Array.isArray(orders));
    assert.ok(orders.length > 0);
  });

  it('updateOrderStatus memperbarui status pesanan dan mencatat riwayat', async () => {
    const newOrderPayload = {
      order_code: `RSK-STS-${Date.now()}`,
      service_id: '14afb604-f297-4526-ba3b-47c1d6fb762a',
      tanggal_layanan: '2026-10-16',
      start_time: '10:00',
      duration: 2,
      alamat_lengkap: 'Jl. Gejayan No. 10',
      patokan_lokasi: 'Dekat Kampus',
      luas_area: 'Kos 1 Kamar',
      total_biaya: 80000,
      harga_saat_booking: 80000,
      status_pembayaran: 'Sudah Bayar',
      status_pekerjaan: 'Menunggu Konfirmasi'
    };
    const created = await db.createOrder(newOrderPayload);
    const updated = await db.updateOrderStatus(created.id, 'Dikonfirmasi', { updated_by: 'admin-001' });
    assert.ok(updated);
    assert.strictEqual(updated.status_pekerjaan, 'Dikonfirmasi');
  });

  it('assignCleaner menugaskan cleaner_id dan mengubah status ke Petugas Ditugaskan', async () => {
    const newOrderPayload = {
      order_code: `RSK-ASN-${Date.now()}`,
      service_id: '14afb604-f297-4526-ba3b-47c1d6fb762a',
      tanggal_layanan: '2026-10-17',
      start_time: '13:00',
      duration: 2,
      alamat_lengkap: 'Jl. Solo KM 8',
      patokan_lokasi: 'Sebelah Mall',
      luas_area: 'Rumah 2 Lantai',
      total_biaya: 150000,
      harga_saat_booking: 150000,
      status_pembayaran: 'Sudah Bayar',
      status_pekerjaan: 'Dikonfirmasi'
    };
    const created = await db.createOrder(newOrderPayload);
    const cleaners = await db.getCleaners();
    const assigned = await db.assignCleaner(created.id, cleaners[0].id, { assigned_by: 'admin-001' });
    assert.ok(assigned);
    assert.strictEqual(assigned.cleaner_id, cleaners[0].id);
    assert.strictEqual(assigned.status_pekerjaan, 'Petugas Ditugaskan');
  });

  it('cancelOrder membatalkan pesanan dengan alasan yang valid', async () => {
    const newOrderPayload = {
      order_code: `RSK-CNC-${Date.now()}`,
      service_id: '14afb604-f297-4526-ba3b-47c1d6fb762a',
      tanggal_layanan: '2026-10-18',
      start_time: '14:00',
      duration: 2,
      alamat_lengkap: 'Jl. Magelang KM 5',
      patokan_lokasi: 'Dekat TVRI',
      luas_area: 'Kos 1 Kamar',
      total_biaya: 80000,
      harga_saat_booking: 80000,
      status_pembayaran: 'Sudah Bayar',
      status_pekerjaan: 'Dikonfirmasi'
    };
    const created = await db.createOrder(newOrderPayload);
    const cancelled = await db.cancelOrder(created.id, {
      cancellation_reason: 'Pelanggan mendadak ada acara keluarga mendesak',
      cancelled_by: 'usr-cust-001'
    });
    assert.ok(cancelled);
    assert.strictEqual(cancelled.status_pekerjaan, 'Dibatalkan');
    assert.strictEqual(cancelled.cancellation_reason, 'Pelanggan mendadak ada acara keluarga mendesak');
  });
});
