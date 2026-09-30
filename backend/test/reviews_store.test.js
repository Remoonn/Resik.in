import test from 'node:test';
import assert from 'node:assert/strict';
import { inMemoryStore, updateCleanerRating } from '../lib/supabase.js';

test('Reviews Store & Rating Aggregation In-Memory Logic', async (t) => {
  await t.test('1. Menambahkan ulasan baru dan menghitung ulang rating_rata_rata cleaner secara otomatis', async () => {
    // Setup test cleaner
    const testCleanerId = 'cln-test-agg-01';
    let cleaner = inMemoryStore.cleaners.find(c => c.id === testCleanerId);
    if (!cleaner) {
      cleaner = {
        id: testCleanerId,
        nama: 'Petugas Test Agg',
        rating_rata_rata: 4.5,
        total_ulasan: 0,
        total_pekerjaan: 5
      };
      inMemoryStore.cleaners.push(cleaner);
    } else {
      cleaner.rating_rata_rata = 4.5;
      cleaner.total_ulasan = 0;
    }

    assert.ok(Array.isArray(inMemoryStore.reviews), 'inMemoryStore.reviews wajib berupa Array');

    // Bersihkan ulasan fixture lama jika ada
    inMemoryStore.reviews = inMemoryStore.reviews.filter(r => r.cleaner_id !== testCleanerId);

    // Masukkan ulasan pertama: rating 5
    inMemoryStore.reviews.push({
      id: 'rev-test-1',
      order_id: 'ord-test-agg-1',
      cleaner_id: testCleanerId,
      customer_id: 'usr-cust-001',
      rating: 5,
      catatan_ulasan: 'Sangat bagus',
      created_at: new Date().toISOString()
    });

    // Masukkan ulasan kedua: rating 4
    inMemoryStore.reviews.push({
      id: 'rev-test-2',
      order_id: 'ord-test-agg-2',
      cleaner_id: testCleanerId,
      customer_id: 'usr-cust-002',
      rating: 4,
      catatan_ulasan: 'Cukup bersih',
      created_at: new Date().toISOString()
    });

    // Panggil helper fungsi updateCleanerRating
    updateCleanerRating(testCleanerId);

    assert.equal(cleaner.rating_rata_rata, 4.5);
    assert.equal(cleaner.total_ulasan, 2);

    // Tambah ulasan ketiga: rating 2 (sehingga (5 + 4 + 2) / 3 = 11 / 3 = 3.666 -> 3.7)
    inMemoryStore.reviews.push({
      id: 'rev-test-3',
      order_id: 'ord-test-agg-3',
      cleaner_id: testCleanerId,
      customer_id: 'usr-cust-003',
      rating: 2,
      catatan_ulasan: 'Kurang bersih',
      created_at: new Date().toISOString()
    });

    updateCleanerRating(testCleanerId);

    assert.equal(cleaner.rating_rata_rata, 3.7);
    assert.equal(cleaner.total_ulasan, 3);
  });
});
