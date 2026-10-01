// backend/test/mapper.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  toDbPaymentStatus,
  fromDbPaymentStatus,
  toDbJobStatus,
  fromDbJobStatus,
  sanitizeCustomerId,
  sanitizeCleanerId,
  orderToApi,
  orderToDb
} from '../lib/mapper.js';

describe('Data Mapper & UUID Sanitizer', () => {
  it('mengonversi status pembayaran dua arah secara akurat', () => {
    assert.strictEqual(toDbPaymentStatus('Belum Bayar'), 'belum_bayar');
    assert.strictEqual(toDbPaymentStatus('Sudah Bayar'), 'sudah_bayar');
    assert.strictEqual(fromDbPaymentStatus('belum_bayar'), 'Belum Bayar');
    assert.strictEqual(fromDbPaymentStatus('sudah_bayar'), 'Sudah Bayar');
  });

  it('mengonversi 7 status pekerjaan dua arah secara akurat', () => {
    assert.strictEqual(toDbJobStatus('Menunggu Konfirmasi'), 'menunggu_konfirmasi');
    assert.strictEqual(toDbJobStatus('Dikonfirmasi'), 'dikonfirmasi');
    assert.strictEqual(toDbJobStatus('Petugas Ditugaskan'), 'petugas_ditugaskan');
    assert.strictEqual(toDbJobStatus('Menuju Lokasi'), 'menuju_lokasi');
    assert.strictEqual(toDbJobStatus('Tiba di Lokasi'), 'tiba_di_lokasi');
    assert.strictEqual(toDbJobStatus('Sedang Dikerjakan'), 'sedang_dikerjakan');
    assert.strictEqual(toDbJobStatus('Selesai'), 'selesai');
    assert.strictEqual(toDbJobStatus('Dibatalkan'), 'dibatalkan');

    assert.strictEqual(fromDbJobStatus('menunggu_konfirmasi'), 'Menunggu Konfirmasi');
    assert.strictEqual(fromDbJobStatus('sedang_dikerjakan'), 'Sedang Dikerjakan');
    assert.strictEqual(fromDbJobStatus('selesai'), 'Selesai');
  });

  it('sanitizeCustomerId menormalkan UUID valid dan menangani demo string secara aman', () => {
    const validUuid = '123e4567-e89b-12d3-a456-426614174000';
    assert.strictEqual(sanitizeCustomerId(validUuid), validUuid);
    assert.strictEqual(sanitizeCustomerId('usr-customer-001'), null);
    assert.strictEqual(sanitizeCustomerId(''), null);
    assert.strictEqual(sanitizeCustomerId(null), null);
    assert.strictEqual(sanitizeCleanerId('cln-001'), null);
    assert.strictEqual(sanitizeCleanerId(validUuid), validUuid);
  });

  it('orderToApi dan orderToDb mentranslasikan field jam_mulai dan start_time', () => {
    const dbRow = {
      id: '123e4567-e89b-12d3-a456-426614174000',
      order_code: 'RSK-20261001-001',
      customer_id: '123e4567-e89b-12d3-a456-426614174001',
      service_id: '123e4567-e89b-12d3-a456-426614174002',
      cleaner_id: '123e4567-e89b-12d3-a456-426614174003',
      jam_mulai: '10:00',
      duration: 2,
      end_time: '12:00',
      alamat_lengkap: 'Jl. Kaliurang KM 10',
      patokan_lokasi: 'Dekat Masjid',
      luas_area: 'Tipe 36',
      total_biaya: '120000.00',
      harga_saat_booking: '120000.00',
      status_pembayaran: 'sudah_bayar',
      status_pekerjaan: 'dikonfirmasi'
    };
    const apiObj = orderToApi(dbRow);
    assert.strictEqual(apiObj.start_time, '10:00');
    assert.strictEqual(apiObj.status_pembayaran, 'Sudah Bayar');
    assert.strictEqual(apiObj.status_pekerjaan, 'Dikonfirmasi');
    assert.strictEqual(apiObj.total_biaya, 120000);
    assert.strictEqual(apiObj.duration, 2);

    const convertedBack = orderToDb(apiObj);
    assert.strictEqual(convertedBack.jam_mulai, '10:00');
    assert.strictEqual(convertedBack.status_pembayaran, 'sudah_bayar');
    assert.strictEqual(convertedBack.status_pekerjaan, 'dikonfirmasi');
  });
});
