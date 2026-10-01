# Full Supabase Cloud Database & Storage Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengintegrasikan seluruh siklus transaksi Resik.in (`orders`, `cleaners`, `quality_reports`, `reviews`, dan foto komparasi Supabase Storage) ke basis data Supabase PostgreSQL Cloud yang sesungguhnya secara *server-authoritative* dengan pola Repository Dual-Mode.

**Architecture:** Membangun *Data Access Layer* terpusat (`backend/lib/database.js`) dan *Data Mapper* (`backend/lib/mapper.js`) yang menghubungkan route Express ke `supabaseAdmin` (menggunakan `SUPABASE_SERVICE_ROLE_KEY`), beralih otomatis ke *in-memory store* saat `NODE_ENV === 'test'` atau offline, serta melayani foto laporan mutu privat via Signed URL 1 jam.

**Tech Stack:** Node.js, Express.js (ES Module), `@supabase/supabase-js`, PostgreSQL, Flutter/Dart, Jest/Node Test Runner.

**Spec:** [`docs/superpowers/specs/2026-10-01-supabase-cloud-integration-design.md`](../specs/2026-10-01-supabase-cloud-integration-design.md)

## Global Constraints
- `SUPABASE_SERVICE_ROLE_KEY` **HANYA BOLEH DIGUNAKAN DI BACKEND** (`backend/.env`); dilarang keras dibocorkan ke response JSON, mobile client, atau di-commit ke Git.
- Aturan SOT di [docs/BUSINESS-RULES.md](../../BUSINESS-RULES.md) (buffer 30 menit anti-double booking, siklus 7 status, 9-stage validasi laporan mutu, 5-stage validasi ulasan) wajib dipertahankan 100%.
- Kontrak REST API di [docs/API.md](../../API.md) dan model mobile Flutter wajib tetap 100% kompatibel (*zero breaking changes*).
- Seluruh 67 backend automated tests dan 48 mobile tests wajib tetap lulus hijau (*zero regressions*).

---

### Task 1: Environment & Supabase Admin Client Initialization

**Files:**
- Modify: `backend/.env` (tambahkan template / placeholder service role key)
- Modify: `backend/lib/supabase.js`
- Test: `backend/test/supabase_client.test.js`

**Interfaces:**
- Consumes: `process.env.SUPABASE_URL`, `process.env.SUPABASE_ANON_KEY`, `process.env.SUPABASE_SERVICE_ROLE_KEY`
- Produces: `supabaseAdmin`, `isLiveSupabase(): boolean`, `ensureStorageBucket(): Promise<boolean>`

- [ ] **Step 1: Write the failing test for `supabaseAdmin` and `isLiveSupabase()`**

```javascript
// backend/test/supabase_client.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { supabase, supabaseAdmin, isLiveSupabase } from '../lib/supabase.js';

describe('Supabase Client Dual-Mode Initialization', () => {
  it('harus menginisialisasi supabase anon client dan supabaseAdmin', () => {
    assert.ok(supabase, 'Anon client harus terdefinisi');
    assert.ok(supabaseAdmin, 'Admin client harus terdefinisi');
  });

  it('isLiveSupabase harus bernilai boolean yang konsisten dengan environment', () => {
    const isLive = isLiveSupabase();
    assert.strictEqual(typeof isLive, 'boolean');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/supabase_client.test.js`  
Expected: FAIL (`supabaseAdmin is not exported` atau `isLiveSupabase is not a function`).

- [ ] **Step 3: Implement `supabaseAdmin`, `isLiveSupabase()`, dan `ensureStorageBucket()`**

Perbarui `backend/lib/supabase.js`:
```javascript
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

export const supabaseAdmin = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);

export function isLiveSupabase() {
  if (process.env.NODE_ENV === 'test') return false;
  return Boolean(SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY);
}

export async function ensureStorageBucket() {
  if (!isLiveSupabase()) return false;
  try {
    const { data: buckets } = await supabaseAdmin.storage.listBuckets();
    const exists = (buckets || []).some(b => b.name === 'quality-reports');
    if (!exists) {
      await supabaseAdmin.storage.createBucket('quality-reports', {
        public: false,
        fileSizeLimit: 5242880,
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp']
      });
      console.log('[SupabaseStorage] Bucket quality-reports berhasil dibuat.');
    }
    return true;
  } catch (err) {
    console.warn('[SupabaseStorage] Warning ensureStorageBucket:', err.message);
    return false;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/supabase_client.test.js`  
Expected: PASS (2 tests pass).

- [ ] **Step 5: Commit**

```bash
git add backend/lib/supabase.js backend/test/supabase_client.test.js
git commit -m "feat(backend): initialize supabaseAdmin client and dual-mode environment check"
```

---

### Task 2: Bi-Directional Data Mapper & UUID Sanitizer

**Files:**
- Create: `backend/lib/mapper.js`
- Test: `backend/test/mapper.test.js`

**Interfaces:**
- Consumes: Raw database rows from PostgreSQL & request bodies from Express
- Produces: 
  - `toDbPaymentStatus(apiStatus: string): string`
  - `fromDbPaymentStatus(dbStatus: string): string`
  - `toDbJobStatus(apiStatus: string): string`
  - `fromDbJobStatus(dbStatus: string): string`
  - `sanitizeCustomerId(customerId?: string): string | null`
  - `orderToApi(dbOrder: object, service?: object, cleaner?: object): object`
  - `orderToDb(apiPayload: object): object`

- [ ] **Step 1: Write the failing unit tests for `mapper.js`**

```javascript
// backend/test/mapper.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  toDbPaymentStatus,
  fromDbPaymentStatus,
  toDbJobStatus,
  fromDbJobStatus,
  sanitizeCustomerId,
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
    assert.strictEqual(toDbJobStatus('Sedang Dikerjakan'), 'sedang_dikerjakan');
    assert.strictEqual(fromDbJobStatus('sedang_dikerjakan'), 'Sedang Dikerjakan');
    assert.strictEqual(fromDbJobStatus('selesai'), 'Selesai');
  });

  it('sanitizeCustomerId menormalkan UUID valid dan menangani demo string secara aman', () => {
    const validUuid = '123e4567-e89b-12d3-a456-426614174000';
    assert.strictEqual(sanitizeCustomerId(validUuid), validUuid);
    assert.strictEqual(sanitizeCustomerId('usr-customer-001'), null);
    assert.strictEqual(sanitizeCustomerId(''), null);
    assert.strictEqual(sanitizeCustomerId(null), null);
  });

  it('orderToApi dan orderToDb mentranslasikan field jam_mulai dan start_time', () => {
    const dbRow = {
      id: 'ord-123',
      order_code: 'RSK-20261001-001',
      jam_mulai: '10:00',
      duration: 2,
      status_pembayaran: 'sudah_bayar',
      status_pekerjaan: 'dikonfirmasi',
      total_biaya: '120000.00'
    };
    const apiObj = orderToApi(dbRow);
    assert.strictEqual(apiObj.start_time, '10:00');
    assert.strictEqual(apiObj.status_pembayaran, 'Sudah Bayar');
    assert.strictEqual(apiObj.status_pekerjaan, 'Dikonfirmasi');
    assert.strictEqual(apiObj.total_biaya, 120000);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/mapper.test.js`  
Expected: FAIL (`Cannot find module '../lib/mapper.js'`).

- [ ] **Step 3: Implement `backend/lib/mapper.js`**

```javascript
// backend/lib/mapper.js
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const PAYMENT_STATUS_MAP = {
  'Belum Bayar': 'belum_bayar',
  'Sudah Bayar': 'sudah_bayar'
};

const JOB_STATUS_MAP = {
  'Menunggu Konfirmasi': 'menunggu_konfirmasi',
  'Dikonfirmasi': 'dikonfirmasi',
  'Petugas Ditugaskan': 'petugas_ditugaskan',
  'Menuju Lokasi': 'menuju_lokasi',
  'Tiba di Lokasi': 'tiba_di_lokasi',
  'Sedang Dikerjakan': 'sedang_dikerjakan',
  'Selesai': 'selesai',
  'Dibatalkan': 'dibatalkan'
};

const REVERSE_PAYMENT_STATUS_MAP = Object.fromEntries(
  Object.entries(PAYMENT_STATUS_MAP).map(([k, v]) => [v, k])
);

const REVERSE_JOB_STATUS_MAP = Object.fromEntries(
  Object.entries(JOB_STATUS_MAP).map(([k, v]) => [v, k])
);

export function toDbPaymentStatus(apiStatus) {
  return PAYMENT_STATUS_MAP[apiStatus] || 'belum_bayar';
}

export function fromDbPaymentStatus(dbStatus) {
  return REVERSE_PAYMENT_STATUS_MAP[dbStatus] || 'Belum Bayar';
}

export function toDbJobStatus(apiStatus) {
  return JOB_STATUS_MAP[apiStatus] || 'menunggu_konfirmasi';
}

export function fromDbJobStatus(dbStatus) {
  return REVERSE_JOB_STATUS_MAP[dbStatus] || 'Menunggu Konfirmasi';
}

export function sanitizeCustomerId(customerId) {
  if (!customerId || typeof customerId !== 'string') return null;
  return UUID_REGEX.test(customerId.trim()) ? customerId.trim() : null;
}

export function sanitizeCleanerId(cleanerId) {
  if (!cleanerId || typeof cleanerId !== 'string') return null;
  return UUID_REGEX.test(cleanerId.trim()) ? cleanerId.trim() : null;
}

export function orderToApi(dbRow, service = null, cleaner = null) {
  if (!dbRow) return null;
  return {
    id: dbRow.id,
    order_code: dbRow.order_code,
    customer_id: dbRow.customer_id,
    service_id: dbRow.service_id,
    cleaner_id: dbRow.cleaner_id,
    preferensi_petugas_id: dbRow.preferensi_petugas_id,
    tanggal_layanan: dbRow.tanggal_layanan,
    start_time: dbRow.jam_mulai || dbRow.start_time,
    end_time: dbRow.end_time || null,
    duration: Number(dbRow.duration || 2),
    alamat_lengkap: dbRow.alamat_lengkap,
    patokan_lokasi: dbRow.patokan_lokasi,
    luas_area: dbRow.luas_area,
    catatan_khusus: dbRow.catatan_khusus,
    harga_saat_booking: Number(dbRow.harga_saat_booking || dbRow.total_biaya || 0),
    total_biaya: Number(dbRow.total_biaya || 0),
    status_pembayaran: fromDbPaymentStatus(dbRow.status_pembayaran),
    payment_timestamp: dbRow.payment_timestamp,
    status_pekerjaan: fromDbJobStatus(dbRow.status_pekerjaan),
    started_at: dbRow.started_at,
    cancellation_reason: dbRow.cancellation_reason,
    cancelled_by: dbRow.cancelled_by,
    cancelled_at: dbRow.cancelled_at,
    created_at: dbRow.created_at,
    service: service || null,
    cleaner: cleaner || null
  };
}

export function orderToDb(apiPayload) {
  return {
    id: apiPayload.id,
    order_code: apiPayload.order_code,
    customer_id: sanitizeCustomerId(apiPayload.customer_id),
    service_id: apiPayload.service_id,
    cleaner_id: sanitizeCleanerId(apiPayload.cleaner_id),
    preferensi_petugas_id: sanitizeCleanerId(apiPayload.preferensi_petugas_id),
    alamat_lengkap: apiPayload.alamat_lengkap,
    patokan_lokasi: apiPayload.patokan_lokasi,
    luas_area: apiPayload.luas_area,
    catatan_khusus: apiPayload.catatan_khusus || null,
    tanggal_layanan: apiPayload.tanggal_layanan,
    jam_mulai: apiPayload.start_time || apiPayload.jam_mulai,
    duration: Number(apiPayload.duration || 2),
    end_time: apiPayload.end_time || null,
    harga_saat_booking: Number(apiPayload.harga_saat_booking || apiPayload.total_biaya),
    total_biaya: Number(apiPayload.total_biaya),
    status_pembayaran: toDbPaymentStatus(apiPayload.status_pembayaran),
    payment_timestamp: apiPayload.payment_timestamp || null,
    status_pekerjaan: toDbJobStatus(apiPayload.status_pekerjaan),
    started_at: apiPayload.started_at || null,
    cancellation_reason: apiPayload.cancellation_reason || null,
    cancelled_by: sanitizeCustomerId(apiPayload.cancelled_by),
    cancelled_at: apiPayload.cancelled_at || null
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/mapper.test.js`  
Expected: PASS (4 tests pass).

- [ ] **Step 5: Commit**

```bash
git add backend/lib/mapper.js backend/test/mapper.test.js
git commit -m "feat(backend): implement bi-directional data mapper and uuid sanitizer"
```

---

### Task 3: Unified Database Repository Layer — Cleaners & Reputation

**Files:**
- Create: `backend/lib/database.js` (fondasi utama dan cleaner repo)
- Modify: `backend/routes/cleaners.js`
- Test: `backend/test/database_cleaners.test.js`

**Interfaces:**
- Consumes: `supabaseAdmin`, `inMemoryStore`, `isLiveSupabase`
- Produces: `db.getCleaners()`, `db.getCleanerById(id)`, `db.updateCleanerRating(cleanerId)`

- [ ] **Step 1: Write the failing test for cleaner repository**

```javascript
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
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/database_cleaners.test.js`  
Expected: FAIL (`Cannot find module '../lib/database.js'`).

- [ ] **Step 3: Implement `backend/lib/database.js` (Scaffolding & Cleaner Methods)**

```javascript
// backend/lib/database.js
import { supabaseAdmin, inMemoryStore, isLiveSupabase, saveStateToDisk } from './supabase.js';

export const db = {
  // CLEANERS REPO
  async getCleaners() {
    if (isLiveSupabase()) {
      try {
        const { data, error } = await supabaseAdmin
          .from('cleaners')
          .select('*')
          .order('rating_rata_rata', { ascending: false });
        if (!error && data && data.length > 0) {
          return data;
        }
      } catch (err) {
        console.warn('[db.getCleaners] Fallback ke in-memory:', err.message);
      }
    }
    return inMemoryStore.cleaners;
  },

  async getCleanerById(cleanerId) {
    if (isLiveSupabase()) {
      try {
        const { data, error } = await supabaseAdmin
          .from('cleaners')
          .select('*')
          .eq('id', cleanerId)
          .maybeSingle();
        if (!error && data) {
          return data;
        }
      } catch (err) {
        console.warn('[db.getCleanerById] Fallback ke in-memory:', err.message);
      }
    }
    return inMemoryStore.cleaners.find(c => c.id === cleanerId) || null;
  },

  async updateCleanerRating(cleanerId) {
    if (isLiveSupabase()) {
      try {
        const { data: reviews, error } = await supabaseAdmin
          .from('reviews')
          .select('rating')
          .eq('cleaner_id', cleanerId);
        if (!error && reviews) {
          const total = reviews.length;
          const sum = reviews.reduce((acc, r) => acc + Number(r.rating), 0);
          const avg = total > 0 ? Math.round((sum / total) * 10) / 10 : 0;

          const { data: updated } = await supabaseAdmin
            .from('cleaners')
            .update({ rating_rata_rata: avg, total_ulasan: total })
            .eq('id', cleanerId)
            .select()
            .maybeSingle();
          if (updated) return updated;
        }
      } catch (err) {
        console.warn('[db.updateCleanerRating] Fallback ke in-memory:', err.message);
      }
    }
    // Fallback in-memory logic
    const reviews = (inMemoryStore.reviews || []).filter(r => r.cleaner_id === cleanerId);
    const cleaner = inMemoryStore.cleaners.find(c => c.id === cleanerId);
    if (!cleaner) return null;
    if (reviews.length === 0) {
      cleaner.total_ulasan = 0;
      return cleaner;
    }
    const sum = reviews.reduce((acc, curr) => acc + curr.rating, 0);
    cleaner.rating_rata_rata = Math.round((sum / reviews.length) * 10) / 10;
    cleaner.total_ulasan = reviews.length;
    saveStateToDisk();
    return cleaner;
  }
};
```

- [ ] **Step 4: Update `backend/routes/cleaners.js` to consume `db`**

Ganti pembacaan langsung `inMemoryStore.cleaners` dengan `await db.getCleaners()` dan `await db.getCleanerById()`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `node --test backend/test/database_cleaners.test.js`  
Expected: PASS (2 tests pass).

- [ ] **Step 6: Commit**

```bash
git add backend/lib/database.js backend/routes/cleaners.js backend/test/database_cleaners.test.js
git commit -m "feat(backend): implement cleaners repository with dual-mode support"
```

---

### Task 4: Unified Database Repository Layer — Orders & Status Lifecycle

**Files:**
- Modify: `backend/lib/database.js`
- Modify: `backend/routes/orders.js`
- Test: `backend/test/database_orders.test.js`

**Interfaces:**
- Consumes: `supabaseAdmin`, `inMemoryStore`, `mapper.js`
- Produces:
  - `db.createOrder(orderData): Promise<Order>`
  - `db.getOrderById(orderId): Promise<Order | null>`
  - `db.getOrders(filters?: object): Promise<Order[]>`
  - `db.updateOrderStatus(orderId, nextStatus, metadata): Promise<Order>`
  - `db.assignCleaner(orderId, cleanerId, auditData): Promise<Order>`
  - `db.cancelOrder(orderId, cancelData): Promise<Order>`

- [ ] **Step 1: Write the failing tests for orders repository**

```javascript
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
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/database_orders.test.js`  
Expected: FAIL (`db.createOrder is not a function`).

- [ ] **Step 3: Implement Orders Methods in `backend/lib/database.js`**

Tambahkan method `createOrder`, `getOrderById`, `getOrders`, `updateOrderStatus`, `assignCleaner`, `cancelOrder` ke objek `db` dengan pemanggilan `supabaseAdmin` di mode live dan fallback ke `inMemoryStore`. Gunakan `orderToDb` dan `orderToApi` dari `mapper.js`.

- [ ] **Step 4: Refactor `backend/routes/orders.js` to consume `db`**

Ganti mutasi array `inMemoryStore.orders` dengan pemanggilan `db.*`. Pastikan validasi bentrok jadwal buffer 30 menit dan gerbang status sekuensial tetap diuji sebelum memanggil `db.updateOrderStatus` / `db.assignCleaner`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `node --test backend/test/database_orders.test.js`  
Expected: PASS.

Run: `npm test`  
Expected: Seluruh 67 backend automated tests tetap lulus (100% green).

- [ ] **Step 6: Commit**

```bash
git add backend/lib/database.js backend/routes/orders.js backend/test/database_orders.test.js
git commit -m "feat(backend): implement orders repository with lifecycle transitions and status audit logs"
```

---

### Task 5: Unified Database Repository Layer — Quality Reports & Supabase Storage

**Files:**
- Modify: `backend/lib/database.js`
- Modify: `backend/routes/quality-reports.js`
- Test: `backend/test/database_quality_reports.test.js`

**Interfaces:**
- Consumes: `supabaseAdmin`, `inMemoryStore`, `ensureStorageBucket`
- Produces:
  - `db.saveQualityReport(reportData): Promise<QualityReport>`
  - `db.getQualityReportByOrderId(orderId): Promise<QualityReport | null>`
  - `db.uploadQualityReportPhoto(orderId, type, buffer, mimeType): Promise<string>`
  - `db.getQualityReportSignedUrl(path): Promise<string>`

- [ ] **Step 1: Write the failing test for Quality Reports repository**

```javascript
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
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/database_quality_reports.test.js`  
Expected: FAIL (`db.saveQualityReport is not a function`).

- [ ] **Step 3: Implement Quality Reports & Storage Methods in `backend/lib/database.js`**

Implementasikan penyimpanan laporan ke tabel `public.quality_reports` serta penanganan upload/signed URL ke bucket `quality-reports`.

- [ ] **Step 4: Update `backend/routes/quality-reports.js` to consume `db`**

Alihkan penyimpanan laporan mutu di `POST /api/quality-reports` dan pengambilan di `GET /api/quality-reports/:order_id` ke `db.saveQualityReport` dan `db.getQualityReportSignedUrl`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `node --test backend/test/database_quality_reports.test.js`  
Expected: PASS.

Run: `node --test backend/test/quality_reports.test.js`  
Expected: PASS (seluruh 9-stage validation pipeline tetap lulus).

- [ ] **Step 6: Commit**

```bash
git add backend/lib/database.js backend/routes/quality-reports.js backend/test/database_quality_reports.test.js
git commit -m "feat(backend): implement quality reports repository and supabase storage integration"
```

---

### Task 6: Unified Database Repository Layer — Customer Reviews & Rating Sync

**Files:**
- Modify: `backend/lib/database.js`
- Modify: `backend/routes/reviews.js`
- Test: `backend/test/database_reviews.test.js`

**Interfaces:**
- Consumes: `supabaseAdmin`, `inMemoryStore`, `mapper.js`
- Produces:
  - `db.createReview(reviewData): Promise<Review>`
  - `db.getReviewsByCleanerId(cleanerId): Promise<Review[]>`
  - `db.getReviewByOrderId(orderId): Promise<Review | null>`

- [ ] **Step 1: Write the failing test for Reviews repository**

```javascript
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
      service_nama: 'Pembersihan Rumah',
      rating: 5,
      ulasan: 'Layanan sangat memuaskan!'
    };

    const saved = await db.createReview(reviewPayload);
    assert.ok(saved);
    assert.strictEqual(saved.rating, 5);

    const fetched = await db.getReviewByOrderId(reviewPayload.order_id);
    assert.ok(fetched);
    assert.strictEqual(fetched.ulasan, reviewPayload.ulasan);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/database_reviews.test.js`  
Expected: FAIL (`db.createReview is not a function`).

- [ ] **Step 3: Implement Reviews Methods in `backend/lib/database.js`**

Implementasikan penyimpanan ulasan ke `public.reviews` dan sinkronisasi agregasi rating cleaner via `db.updateCleanerRating`.

- [ ] **Step 4: Update `backend/routes/reviews.js` to consume `db`**

Ganti mutasi langsung array memori dengan `db.createReview`, `db.getReviewsByCleanerId`, dan `db.getReviewByOrderId`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `node --test backend/test/database_reviews.test.js`  
Expected: PASS.

Run: `node --test backend/test/reviews.test.js`  
Expected: PASS (seluruh 5-stage validation pipeline tetap lulus).

- [ ] **Step 6: Commit**

```bash
git add backend/lib/database.js backend/routes/reviews.js backend/test/database_reviews.test.js
git commit -m "feat(backend): implement reviews repository with automatic reputation sync"
```

---

### Task 7: Full Regression Suite & Live Physical Device Verification

**Files:**
- Verify: Full repository test suite (`backend/` & `mobile/`)
- Verify: Live connection to Supabase Cloud Dashboard

- [ ] **Step 1: Run complete backend regression test suite**

Run: `cd backend && npm test`  
Expected: 67/67 tests passing across all suites.

- [ ] **Step 2: Run mobile analyzer and widget tests**

Run: `cd mobile && flutter analyze`  
Expected: 0 issues.

Run: `cd mobile && flutter test`  
Expected: 48/48 tests passing.

- [ ] **Step 3: Live End-to-End Test on Physical Device (Samsung Galaxy A52)**

1. Aktifkan port forwarding ADB:
   `adb -s 10.63.68.57:36883 reverse tcp:3000 tcp:3000`
2. Jalankan backend Express:
   `cd backend && npm run dev`
3. Jalankan aplikasi Flutter:
   `cd mobile && flutter run -d 10.63.68.57:36883`
4. Lakukan alur pengujian lengkap:
   - Buat pesanan baru $\rightarrow$ Cek baris baru di tabel `public.orders` Supabase Cloud Dashboard.
   - Bayar pesanan $\rightarrow$ Cek status pembayaran menjadi `sudah_bayar` di Supabase.
   - Tugaskan petugas $\rightarrow$ Cek `cleaner_id` tercatat di Supabase.
   - Kirim Laporan Mutu $\rightarrow$ Cek foto di Supabase Storage bucket `quality-reports` dan record di `public.quality_reports`.
   - Kirim Rating & Ulasan $\rightarrow$ Cek baris di `public.reviews` dan rating cleaner di `public.cleaners`.

- [ ] **Step 4: Commit any final configurations and verification proof**

```bash
git add -A
git commit -m "chore(supabase): verify complete real persistence integration on physical device"
```
