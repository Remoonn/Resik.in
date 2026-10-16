import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { midtransHelper } from '../lib/midtrans.js';

test('Midtrans Helper Unit Tests', async (t) => {
  await t.test('1. verifySignature menghasilkan hash SHA-512 yang valid dan mendeteksi manipulasi', () => {
    const orderId = 'ord-test-001';
    const statusCode = '200';
    const grossAmount = '150000.00';
    const serverKey = 'SB-Mid-server-TEST12345';

    // Perhitungan manual SHA-512
    const expected = crypto.createHash('sha512')
      .update(orderId + statusCode + grossAmount + serverKey)
      .digest('hex');

    const isValid = midtransHelper.verifySignature({
      orderId,
      statusCode,
      grossAmount,
      signatureKey: expected,
      serverKeyOverride: serverKey
    });
    assert.strictEqual(isValid, true, 'Signature harus cocok');

    const isInvalid = midtransHelper.verifySignature({
      orderId,
      statusCode,
      grossAmount,
      signatureKey: 'tampered-signature-hash',
      serverKeyOverride: serverKey
    });
    assert.strictEqual(isInvalid, false, 'Signature palsu harus ditolak');
  });

  await t.test('2. createSnapTransaction fallback ke Mock Mode saat forceMock aktif', async () => {
    const snap = await midtransHelper.createSnapTransaction({
      orderId: 'ord-mock-001',
      grossAmount: 150000,
      customerDetails: { first_name: 'Budi', email: 'budi@example.com' },
      forceMock: true
    });

    assert.ok(snap.token, 'Snap token harus ada');
    assert.ok(snap.redirect_url, 'Redirect URL harus ada');
    assert.strictEqual(snap.is_mock, true, 'Harus berstatus is_mock: true');
    assert.match(snap.redirect_url, /mock-snap-ord-mock-001/, 'URL harus mengarah ke sesi mock');
  });

  await t.test('3. checkTransactionStatus mengembalikan status transaksi yang valid', async () => {
    const mockStatus = await midtransHelper.checkTransactionStatus('ord-mock-001', {
      forceMockStatus: {
        status_code: '200',
        transaction_status: 'settlement',
        payment_type: 'qris',
        transaction_id: 'mock-txn-001',
        settlement_time: '2026-10-17T00:00:00.000Z'
      }
    });

    assert.strictEqual(mockStatus.transaction_status, 'settlement');
    assert.strictEqual(mockStatus.payment_type, 'qris');
  });
});
