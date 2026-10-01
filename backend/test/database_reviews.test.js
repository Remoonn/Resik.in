// backend/test/database_reviews.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../lib/database.js';

describe('Database Repository - Reviews', () => {
  it('createReview menyimpan ulasan dan getReviewByOrderId mengambil ulasan terkait', async () => {
    const reviewPayload = {
      order_id: 'ord-test-rev-repo-01',
      cleaner_id: 'cln-001',
      customer_id: 'usr-customer-001',
      customer_nama: 'Budi Santoso',
      rating: 5,
      catatan_ulasan: 'Layanan sangat memuaskan!'
    };

    const saved = await db.createReview(reviewPayload);
    assert.ok(saved);
    assert.strictEqual(saved.rating, 5);

    const fetched = await db.getReviewByOrderId(reviewPayload.order_id);
    assert.ok(fetched);
    assert.strictEqual(fetched.catatan_ulasan || fetched.ulasan, reviewPayload.catatan_ulasan);
  });

  it('getReviewsByCleanerId mengembalikan daftar ulasan untuk seorang petugas', async () => {
    const reviews = await db.getReviewsByCleanerId('cln-001');
    assert.ok(Array.isArray(reviews));
  });
});
