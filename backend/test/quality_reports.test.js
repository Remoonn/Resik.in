// backend/test/quality_reports.test.js
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
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
