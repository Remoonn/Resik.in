// backend/test/database_cleaners.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../lib/database.js';

describe('Database Repository - Cleaners', () => {
  it('getCleaners mengembalikan daftar petugas kebersihan aktif', async () => {
    const cleaners = await db.getCleaners();
    assert.ok(Array.isArray(cleaners));
    assert.ok(cleaners.length > 0);
    assert.ok(cleaners[0].nama);
    assert.ok(cleaners[0].keahlian);
  });

  it('getCleanerById mengembalikan cleaner jika id ditemukan dan null jika tidak', async () => {
    const cleaners = await db.getCleaners();
    const targetId = cleaners[0].id;
    const cleaner = await db.getCleanerById(targetId);
    assert.ok(cleaner);
    assert.strictEqual(cleaner.id, targetId);

    const nonExistent = await db.getCleanerById('non-existent-cleaner-id');
    assert.strictEqual(nonExistent, null);
  });

  it('updateCleanerRating memperbarui rating_rata_rata dan total_ulasan petugas', async () => {
    const cleaners = await db.getCleaners();
    const targetId = cleaners[0].id;
    const updated = await db.updateCleanerRating(targetId);
    assert.ok(updated);
    assert.strictEqual(updated.id, targetId);
    assert.ok(typeof updated.rating_rata_rata === 'number');
    assert.ok(typeof updated.total_ulasan === 'number');
  });
});
