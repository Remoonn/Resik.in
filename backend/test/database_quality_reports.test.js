// backend/test/database_quality_reports.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../lib/database.js';

describe('Database Repository - Quality Reports', () => {
  it('saveQualityReport menyimpan laporan mutu dan getQualityReportByOrderId mengambilnya', async () => {
    const reportPayload = {
      order_id: 'ord-test-qr-repo-01',
      cleaner_id: 'cln-001',
      checklist_area: [
        { area: 'Kamar Tidur', completed: true },
        { area: 'Kamar Mandi', completed: true }
      ],
      foto_before_url: 'orders/ord-test-qr-repo-01/before.jpg',
      foto_after_url: 'orders/ord-test-qr-repo-01/after.jpg',
      catatan_petugas: 'Selesai pembersihan mendalam',
      started_at: new Date(Date.now() - 3600000).toISOString(),
      completed_at: new Date().toISOString()
    };

    const saved = await db.saveQualityReport(reportPayload);
    assert.ok(saved);
    assert.strictEqual(saved.order_id, reportPayload.order_id);

    const fetched = await db.getQualityReportByOrderId(reportPayload.order_id);
    assert.ok(fetched);
    assert.strictEqual(fetched.catatan_petugas, reportPayload.catatan_petugas);
  });

  it('getQualityReportSignedUrl mengembalikan URL yang valid untuk path berkas', async () => {
    const signedUrl = await db.getQualityReportSignedUrl('orders/ord-test-qr-repo-01/before.jpg');
    assert.ok(signedUrl);
    assert.ok(typeof signedUrl === 'string');
    assert.ok(signedUrl.length > 0);
  });

  it('uploadQualityReportPhoto menyimpan berkas foto dan mengembalikan storage path', async () => {
    const dummyBuffer = Buffer.from('fake-image-bytes');
    const path = await db.uploadQualityReportPhoto('ord-test-qr-repo-01', 'before', dummyBuffer, 'image/jpeg');
    assert.ok(path);
    assert.strictEqual(path, 'orders/ord-test-qr-repo-01/before.jpg');
  });
});
