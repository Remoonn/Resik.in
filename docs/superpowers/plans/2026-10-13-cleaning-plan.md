# Cleaning Plan (FR-12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun subsistem Cleaning Plan (Layanan Rutin Berkala & Paket Langganan Cerdas) secara end-to-end, mencakup skema basis data relasional, engine penjadwalan deterministik, REST API Express.js, dual generator sesi (otomatis & trigger sidang), serta antarmuka Flutter Material 3 yang terhubung ke siklus 7 status pesanan.

**Architecture:** Modul terisolasi dengan entitas `cleaning_plans` yang berelasi ke `users` (pelanggan), `cleaners` (petugas favorit), dan ditautkan ke tabel `orders` melalui foreign key `cleaning_plan_id`. Backend menggunakan engine penjadwalan deterministik (`cleaning-plan-engine.js`) dengan penanganan idempotensi dan graceful conflict fallback. Mobile Flutter menyediakan layar manajemen langganan `CleaningPlansScreen`, formulir pendaftaran `CreateCleaningPlanScreen`, integrasi Banner Beranda/Tab Pesanan, serta lencana khusus pada `OrderTrackingScreen`.

**Tech Stack:** Node.js (Express ES Module), Supabase PostgreSQL / In-Memory Store, Flutter 3.x (Dart), Material 3 Design System.

**Spec:** [`docs/superpowers/specs/2026-10-13-cleaning-plan-design.md`](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/superpowers/specs/2026-10-13-cleaning-plan-design.md)

## Global Constraints
- Target Rilis: Resik.in V2.0 / Phase 3 (FR-12).
- Zero External Dependencies: Penjadwalan murni JavaScript native `Date` tanpa library eksternal.
- Minimal Diff Principle: Jangan merestrukturisasi kode eksisting di luar cakupan yang diminta.
- Anti-Double Booking Rule: Interval kerja $\text{end\_time} = \text{start\_time} + \text{duration}$ ditambah buffer 30 menit.
- Idempotensi Mutlak: Sesi untuk tanggal target yang sama tidak boleh dibuat ganda.
- TDD Workflow: Red-Green-Refactor dengan komit modular per task.
- Zero Warnings Bar: `flutter analyze` 0 issues dan 100% test pass.

---

### Task 1: Database Schema & In-Memory Store Integration

**Files:**
- Modify: `database/schema.sql`
- Modify: `backend/lib/database.js`
- Test: `backend/test/cleaning_plan_database.test.js`

**Interfaces:**
- Produces: `db.cleaningPlans` array dan query methods (`createCleaningPlan`, `getCleaningPlansByCustomerId`, `getCleaningPlanById`, `updateCleaningPlanStatus`, `updateCleaningPlanNextSession`).

- [ ] **Step 1: Write the failing test for cleaning plans database store**

Buat file `backend/test/cleaning_plan_database.test.js`:
```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../lib/database.js';

test('Cleaning Plan Database Store Tests', async (t) => {
  await t.test('1. Menyimpan dan mengambil cleaning plan baru', () => {
    const plan = db.createCleaningPlan({
      customerId: 'usr-cust-test-01',
      planName: 'Langganan Bersih Kos',
      serviceCategory: 'kos',
      serviceId: 'srv-002',
      frequency: 'mingguan',
      dayOfWeek: 1,
      dayName: 'Senin',
      startTime: '09:00',
      duration: 2,
      pricePerSession: 100000,
      address: 'Jl. Kaliurang KM 14.5 No. 4',
      landmark: 'Pagar hitam',
      notes: 'Kamar mandi & balkon',
      preferredCleanerId: 'cln-001',
      nextSessionDate: '2026-10-19'
    });

    assert.ok(plan.id, 'Plan harus memiliki ID yang ter-generate');
    assert.equal(plan.planName, 'Langganan Bersih Kos');
    assert.equal(plan.status, 'Aktif');
    assert.equal(plan.totalSessionsCompleted, 0);

    const fetched = db.getCleaningPlanById(plan.id);
    assert.equal(fetched.id, plan.id);
    assert.equal(fetched.dayOfWeek, 1);
  });

  await t.test('2. Mengambil daftar plan berdasarkan customerId', () => {
    const customerPlans = db.getCleaningPlansByCustomerId('usr-cust-test-01');
    assert.ok(customerPlans.length >= 1);
    assert.equal(customerPlans[0].customerId, 'usr-cust-test-01');
  });

  await t.test('3. Memperbarui status cleaning plan', () => {
    const plans = db.getCleaningPlansByCustomerId('usr-cust-test-01');
    const planId = plans[0].id;

    const paused = db.updateCleaningPlanStatus(planId, 'Dijeda');
    assert.equal(paused.status, 'Dijeda');

    const active = db.updateCleaningPlanStatus(planId, 'Aktif');
    assert.equal(active.status, 'Aktif');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/cleaning_plan_database.test.js`
Expected: FAIL with `db.createCleaningPlan is not a function`.

- [ ] **Step 3: Implement database schema updates & inMemoryStore methods**

1. Perbarui `database/schema.sql` dengan menambahkan tabel `cleaning_plans` dan alterasi tabel `orders`.
2. Di `backend/lib/database.js`:
   - Tambahkan inisialisasi `cleaningPlans: []` pada `inMemoryStore`.
   - Implementasikan fungsi-fungsi helper di objek `db`:
     - `createCleaningPlan(planData)`
     - `getCleaningPlansByCustomerId(customerId)`
     - `getCleaningPlanById(planId)`
     - `updateCleaningPlanStatus(planId, status)`
     - `updateCleaningPlanNextSession(planId, nextDate, incrementCompleted)`

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/cleaning_plan_database.test.js`
Expected: PASS (3/3 tests pass).

- [ ] **Step 5: Commit Task 1**

```bash
git add database/schema.sql backend/lib/database.js backend/test/cleaning_plan_database.test.js
git commit -m "feat(database): add cleaning_plans schema and in-memory store query methods"
```

---

### Task 2: Deterministic Scheduling Engine & Order Generator

**Files:**
- Create: `backend/lib/cleaning-plan-engine.js`
- Test: `backend/test/cleaning_plan_engine.test.js`

**Interfaces:**
- Consumes: `db` dari `backend/lib/database.js`
- Produces: `calculateNextSessionDate({ dayOfWeek, frequency, fromDate })`, `generateNextSessionOrder({ plan, existingOrders, cleaners })`.

- [ ] **Step 1: Write the failing test for cleaning plan engine**

Buat file `backend/test/cleaning_plan_engine.test.js`:
```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateNextSessionDate, generateNextSessionOrder } from '../lib/cleaning-plan-engine.js';

test('Cleaning Plan Engine Unit Tests', async (t) => {
  await t.test('1. calculateNextSessionDate: menghitung target hari mingguan (+7 hari atau hari terdekat)', () => {
    // 2026-10-13 adalah Selasa (dayOfWeek: 2)
    const baseDate = new Date('2026-10-13T10:00:00.000Z');
    
    // Target Senin (dayOfWeek: 1) berikutnya: 2026-10-19
    const nextMonday = calculateNextSessionDate({
      dayOfWeek: 1,
      frequency: 'mingguan',
      fromDate: baseDate
    });
    assert.equal(nextMonday, '2026-10-19');

    // Target Selasa minggu depan jika jam sudah lewat: 2026-10-20
    const nextTuesday = calculateNextSessionDate({
      dayOfWeek: 2,
      frequency: 'mingguan',
      fromDate: baseDate,
      startTime: '08:00', // Sudah lewat dari 10:00
      currentTimeStr: '10:00'
    });
    assert.equal(nextTuesday, '2026-10-20');
  });

  await t.test('2. calculateNextSessionDate: menghitung target dua mingguan (+14 hari)', () => {
    const baseDate = new Date('2026-10-19T09:00:00.000Z');
    const biweekly = calculateNextSessionDate({
      dayOfWeek: 1,
      frequency: 'dua_mingguan',
      fromDate: baseDate,
      skipFirstInterval: true
    });
    assert.equal(biweekly, '2026-11-02');
  });

  await t.test('3. generateNextSessionOrder: membentuk order dengan session_number dan cleaning_plan_id', () => {
    const mockPlan = {
      id: 'plan-test-001',
      customerId: 'usr-cust-001',
      planName: 'Kos Rutin',
      serviceCategory: 'kos',
      serviceId: 'srv-002',
      frequency: 'mingguan',
      dayOfWeek: 1,
      dayName: 'Senin',
      startTime: '09:00',
      duration: 2,
      pricePerSession: 100000,
      address: 'Jl. Kaliurang KM 14.5 No. 4',
      landmark: 'Pagar hitam',
      notes: 'Bersih kamar mandi',
      preferredCleanerId: 'cln-001',
      status: 'Aktif',
      nextSessionDate: '2026-10-19',
      totalSessionsCompleted: 2
    };

    const order = generateNextSessionOrder({
      plan: mockPlan,
      existingOrders: []
    });

    assert.ok(order.id);
    assert.equal(order.customer_id, 'usr-cust-001');
    assert.equal(order.cleaner_id, 'cln-001');
    assert.equal(order.cleaning_plan_id, 'plan-test-001');
    assert.equal(order.session_number, 3);
    assert.equal(order.status, 'Menunggu Konfirmasi');
    assert.equal(order.status_pembayaran, 'Belum Bayar');
    assert.ok(order.start_time.startsWith('2026-10-19'));
  });

  await t.test('4. conflict fallback: alihkan cleaner_id ke null jika petugas favorit bentrok', () => {
    const mockPlan = {
      id: 'plan-test-001',
      customerId: 'usr-cust-001',
      planName: 'Kos Rutin',
      serviceCategory: 'kos',
      serviceId: 'srv-002',
      frequency: 'mingguan',
      dayOfWeek: 1,
      startTime: '09:00',
      duration: 2,
      pricePerSession: 100000,
      address: 'Jl. Kaliurang',
      preferredCleanerId: 'cln-001',
      status: 'Aktif',
      nextSessionDate: '2026-10-19',
      totalSessionsCompleted: 0
    };

    // Buat order bentrok untuk cln-001 di 2026-10-19 jam 09:00
    const conflictingOrder = {
      id: 'ord-conflict',
      cleaner_id: 'cln-001',
      start_time: '2026-10-19T09:00:00.000Z',
      duration: 2,
      status: 'Dikonfirmasi'
    };

    const order = generateNextSessionOrder({
      plan: mockPlan,
      existingOrders: [conflictingOrder]
    });

    assert.equal(order.cleaner_id, null, 'cleaner_id harus null saat bentrok');
    assert.ok(order.notes.includes('[Jadwal Bentrok]'), 'Notes harus memuat catatan bentrok jadwal');
  });

  await t.test('5. idempotency: menolak jika pesanan untuk tanggal yang sama sudah dibuat', () => {
    const mockPlan = {
      id: 'plan-test-001',
      nextSessionDate: '2026-10-19'
    };
    const existingOrder = {
      id: 'ord-existing',
      cleaning_plan_id: 'plan-test-001',
      start_time: '2026-10-19T09:00:00.000Z'
    };

    assert.throws(() => {
      generateNextSessionOrder({
        plan: mockPlan,
        existingOrders: [existingOrder]
      });
    }, /sudah dibuat/);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/cleaning_plan_engine.test.js`
Expected: FAIL with `Cannot find module '../lib/cleaning-plan-engine.js'`.

- [ ] **Step 3: Implement cleaning-plan-engine.js**

Buat file `backend/lib/cleaning-plan-engine.js`:
- `calculateNextSessionDate({ dayOfWeek, frequency, fromDate, startTime, currentTimeStr, skipFirstInterval })`
- `generateNextSessionOrder({ plan, existingOrders })`
- Helper validasi bentrok jadwal dengan buffer 30 menit.

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/cleaning_plan_engine.test.js`
Expected: PASS (5/5 tests pass).

- [ ] **Step 5: Commit Task 2**

```bash
git add backend/lib/cleaning-plan-engine.js backend/test/cleaning_plan_engine.test.js
git commit -m "feat(engine): implement deterministic scheduling engine and idempotent order generator"
```

---

### Task 3: Backend REST API Route & Express Server Mount

**Files:**
- Create: `backend/routes/cleaning-plans.js`
- Modify: `backend/server.js`
- Test: `backend/test/cleaning_plans.test.js`

**Interfaces:**
- Consumes: `cleaning-plan-engine.js` dan `db` dari `backend/lib/database.js`
- Produces: Router mounted at `/api/cleaning-plans`

- [ ] **Step 1: Write the failing integration test in backend/test/cleaning_plans.test.js**

Buat file `backend/test/cleaning_plans.test.js`:
```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import app from '../server.js';

test('Cleaning Plans REST API Integration Tests', async (t) => {
  let createdPlanId = '';

  await t.test('1. POST /api/cleaning-plans: berhasil membuat plan dan order sesi perdana', async () => {
    const res = await request(app)
      .post('/api/cleaning-plans')
      .send({
        customerId: 'usr-cust-api-01',
        planName: 'Rutin Kos Mahasiswa',
        serviceCategory: 'kos',
        serviceId: 'srv-002',
        frequency: 'mingguan',
        dayOfWeek: 1,
        dayName: 'Senin',
        startTime: '09:00',
        duration: 2,
        address: 'Jl. Kaliurang KM 14.5 Gang Melati No. 8',
        landmark: 'Dekat warung madura',
        notes: 'Fokus bersihkan kamar mandi',
        preferredCleanerId: 'cln-001'
      });

    assert.equal(res.status, 201);
    assert.equal(res.body.success, true);
    assert.ok(res.body.data.plan.id);
    assert.equal(res.body.data.plan.planName, 'Rutin Kos Mahasiswa');
    assert.ok(res.body.data.initialOrder.id);
    assert.equal(res.body.data.initialOrder.session_number, 1);
    assert.equal(res.body.data.initialOrder.status, 'Menunggu Konfirmasi');

    createdPlanId = res.body.data.plan.id;
  });

  await t.test('2. POST /api/cleaning-plans: validasi gagal jika jam di luar 08:00-17:00 atau alamat terlalu pendek', async () => {
    const res = await request(app)
      .post('/api/cleaning-plans')
      .send({
        customerId: 'usr-cust-api-01',
        planName: 'Tes Invalid',
        serviceCategory: 'kos',
        frequency: 'mingguan',
        dayOfWeek: 1,
        dayName: 'Senin',
        startTime: '20:00', // Di luar jam operasional
        duration: 2,
        address: 'Pendek' // Kurang dari 10 karakter
      });

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
  });

  await t.test('3. GET /api/cleaning-plans: mengambil daftar paket pelanggan ter-hidrasi', async () => {
    const res = await request(app)
      .get('/api/cleaning-plans?customer_id=usr-cust-api-01');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.data.length >= 1);
    assert.equal(res.body.data[0].id, createdPlanId);
  });

  await t.test('4. GET /api/cleaning-plans/:id: mengambil rincian detail paket beserta riwayat pesanan', async () => {
    const res = await request(app)
      .get(`/api/cleaning-plans/${createdPlanId}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.plan.id, createdPlanId);
    assert.ok(Array.isArray(res.body.data.orders));
    assert.equal(res.body.data.orders.length, 1);
  });

  await t.test('5. PATCH /api/cleaning-plans/:id/status: jeda dan aktifkan kembali paket', async () => {
    const pauseRes = await request(app)
      .patch(`/api/cleaning-plans/${createdPlanId}/status`)
      .send({ status: 'Dijeda' });

    assert.equal(pauseRes.status, 200);
    assert.equal(pauseRes.body.data.status, 'Dijeda');

    const resumeRes = await request(app)
      .patch(`/api/cleaning-plans/${createdPlanId}/status`)
      .send({ status: 'Aktif' });

    assert.equal(resumeRes.status, 200);
    assert.equal(resumeRes.body.data.status, 'Aktif');
  });

  await t.test('6. POST /api/cleaning-plans/:id/generate-next-session: trigger manual sesi berikutnya untuk sidang', async () => {
    const res = await request(app)
      .post(`/api/cleaning-plans/${createdPlanId}/generate-next-session`);

    assert.equal(res.status, 201);
    assert.equal(res.body.success, true);
    assert.ok(res.body.data.order.id);
    assert.equal(res.body.data.order.session_number, 2);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/cleaning_plans.test.js`
Expected: FAIL with 404 Not Found (router belum di-mount).

- [ ] **Step 3: Implement backend/routes/cleaning-plans.js & mount in backend/server.js**

1. Buat router `backend/routes/cleaning-plans.js` dengan endpoint:
   - `POST /`
   - `GET /`
   - `GET /:id`
   - `PATCH /:id/status`
   - `POST /:id/generate-next-session`
2. Di `backend/server.js`:
   - Import `cleaningPlansRouter` dari `./routes/cleaning-plans.js`
   - Mount: `app.use('/api/cleaning-plans', cleaningPlansRouter);`

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/cleaning_plans.test.js`
Expected: PASS (6/6 tests pass).

- [ ] **Step 5: Run full backend test suite to ensure zero regressions**

Run: `cd backend && npm test`
Expected: PASS (All test suites pass, 106+ tests pass).

- [ ] **Step 6: Commit Task 3**

```bash
git add backend/routes/cleaning-plans.js backend/server.js backend/test/cleaning_plans.test.js
git commit -m "feat(api): add /api/cleaning-plans endpoints and mount in Express server"
```

---

### Task 4: Order Model Backward-Compatibility & Quality Report Hook

**Files:**
- Modify: `mobile/lib/models/order_model.dart`
- Modify: `backend/routes/quality-reports.js`
- Test: `mobile/test/order_model_test.dart`
- Test: `backend/test/quality-reports.test.js`

**Interfaces:**
- Produces: `OrderModel.cleaningPlanId`, `OrderModel.sessionNumber`, dan hook auto-increment `total_sessions_completed` saat order selesai.

- [ ] **Step 1: Write the failing test for order model optional fields in mobile**

Buka `mobile/test/order_model_test.dart`, tambahkan test case:
```dart
test('Order.fromJson mendukung cleaning_plan_id dan session_number secara opsional', () {
  final jsonWithPlan = {
    'id': 'ord-test-plan-01',
    'customer_id': 'usr-001',
    'service_category': 'kos',
    'status': 'Menunggu Konfirmasi',
    'status_pembayaran': 'Belum Bayar',
    'start_time': '2026-10-19T09:00:00.000Z',
    'duration': 2,
    'total_price': 100000,
    'address': 'Jl. Kaliurang KM 14.5',
    'cleaning_plan_id': 'plan-001',
    'session_number': 3,
  };

  final order = Order.fromJson(jsonWithPlan);
  expect(order.cleaningPlanId, 'plan-001');
  expect(order.sessionNumber, 3);

  // Backward-compatibility: JSON lama tanpa field plan
  final jsonOld = {
    'id': 'ord-old-01',
    'customer_id': 'usr-001',
    'service_category': 'rumah',
    'status': 'Selesai',
    'status_pembayaran': 'Sudah Bayar',
    'start_time': '2026-10-10T09:00:00.000Z',
    'duration': 2,
    'total_price': 100000,
    'address': 'Jl. Kaliurang KM 14.5',
  };

  final oldOrder = Order.fromJson(jsonOld);
  expect(oldOrder.cleaningPlanId, isNull);
  expect(oldOrder.sessionNumber, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/order_model_test.dart`
Expected: FAIL (getter `cleaningPlanId` not defined).

- [ ] **Step 3: Update Order model in mobile/lib/models/order_model.dart & backend/routes/quality-reports.js**

1. Di `mobile/lib/models/order_model.dart`:
   - Tambahkan field `final String? cleaningPlanId;` dan `final int? sessionNumber;`
   - Inisialisasi di constructor dan parsing di `fromJson` / `toJson`.
2. Di `backend/routes/quality-reports.js`:
   - Saat order berhasil diselesaikan ke status `Selesai`: jika order memiliki `cleaning_plan_id`, panggil `db.incrementCleaningPlanSessionsCompleted(order.cleaning_plan_id)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/order_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit Task 4**

```bash
git add mobile/lib/models/order_model.dart mobile/test/order_model_test.dart backend/routes/quality-reports.js
git commit -m "feat(orders): add cleaningPlanId & sessionNumber to Order model and sync completed sessions counter"
```

---

### Task 5: Mobile Data Models & ApiService Integration

**Files:**
- Create: `mobile/lib/models/cleaning_plan_model.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Test: `mobile/test/cleaning_plan_model_test.dart`

**Interfaces:**
- Produces: `CleaningPlanModel`, `CleaningPlanCleanerInfo`, dan methods di `ApiService`:
  - `fetchCleaningPlans({String? customerId})`
  - `fetchCleaningPlanDetail(String planId)`
  - `createCleaningPlan(Map<String, dynamic> planData)`
  - `updateCleaningPlanStatus(String planId, String status)`
  - `generateNextCleaningPlanSession(String planId)`

- [ ] **Step 1: Write the failing model test in mobile/test/cleaning_plan_model_test.dart**

Buat file `mobile/test/cleaning_plan_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/cleaning_plan_model.dart';

void main() {
  group('CleaningPlan Model Tests', () {
    test('CleaningPlan.fromJson correctly parses full payload with preferredCleaner', () {
      final json = {
        'id': 'plan-test-01',
        'customerId': 'usr-001',
        'planName': 'Bersih Kos Rutin',
        'serviceCategory': 'kos',
        'serviceId': 'srv-002',
        'frequency': 'mingguan',
        'dayOfWeek': 1,
        'dayName': 'Senin',
        'startTime': '09:00',
        'duration': 2,
        'pricePerSession': 100000,
        'address': 'Jl. Kaliurang KM 14.5 No. 4',
        'landmark': 'Pagar hitam',
        'notes': 'Kamar mandi & balkon',
        'status': 'Aktif',
        'nextSessionDate': '2026-10-19',
        'lastGeneratedDate': '2026-10-13',
        'totalSessionsCompleted': 4,
        'activeOrdersCount': 1,
        'preferredCleaner': {
          'id': 'cln-001',
          'nama': 'Budi Santoso',
          'rating': 4.8,
          'photoUrl': 'https://resik.in/cleaners/budi.jpg'
        }
      };

      final plan = CleaningPlan.fromJson(json);

      expect(plan.id, 'plan-test-01');
      expect(plan.planName, 'Bersih Kos Rutin');
      expect(plan.dayName, 'Senin');
      expect(plan.frequency, 'mingguan');
      expect(plan.pricePerSession, 100000);
      expect(plan.totalSessionsCompleted, 4);
      expect(plan.preferredCleaner, isNotNull);
      expect(plan.preferredCleaner!.nama, 'Budi Santoso');
      expect(plan.preferredCleaner!.rating, 4.8);
    });

    test('CleaningPlan.fromJson handles null preferredCleaner gracefully', () {
      final json = {
        'id': 'plan-test-02',
        'customerId': 'usr-001',
        'planName': 'Bersih Rumah',
        'serviceCategory': 'rumah',
        'frequency': 'dua_mingguan',
        'dayOfWeek': 6,
        'dayName': 'Sabtu',
        'startTime': '10:00',
        'duration': 3,
        'pricePerSession': 150000,
        'address': 'Jl. Palagan KM 10',
        'status': 'Dijeda',
        'nextSessionDate': '2026-10-24',
        'totalSessionsCompleted': 0,
        'preferredCleaner': null
      };

      final plan = CleaningPlan.fromJson(json);
      expect(plan.preferredCleaner, isNull);
      expect(plan.status, 'Dijeda');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/cleaning_plan_model_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:mobile/models/cleaning_plan_model.dart'`.

- [ ] **Step 3: Implement cleaning_plan_model.dart & methods in ApiService**

1. Buat `mobile/lib/models/cleaning_plan_model.dart` dengan class `CleaningPlan` dan `CleaningPlanCleanerInfo`.
2. Di `mobile/lib/services/api_service.dart`, tambahkan:
   - `fetchCleaningPlans({String? customerId})`
   - `fetchCleaningPlanDetail(String planId)`
   - `createCleaningPlan(Map<String, dynamic> planData)`
   - `updateCleaningPlanStatus(String planId, String status)`
   - `generateNextCleaningPlanSession(String planId)`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/cleaning_plan_model_test.dart`
Expected: PASS (2/2 tests pass).

- [ ] **Step 5: Commit Task 5**

```bash
git add mobile/lib/models/cleaning_plan_model.dart mobile/lib/services/api_service.dart mobile/test/cleaning_plan_model_test.dart
git commit -m "feat(mobile): add CleaningPlan model and ApiService methods"
```

---

### Task 6: Mobile UI - Formulir Pendaftaran Paket Langganan (`CreateCleaningPlanScreen`)

**Files:**
- Create: `mobile/lib/screens/create_cleaning_plan_screen.dart`
- Test: `mobile/test/create_cleaning_plan_screen_test.dart`

**Interfaces:**
- Produces: `CreateCleaningPlanScreen` StatefulWidget dengan form validasi, chip frekuensi/hari/durasi, dan integrasi API pembuatan paket.

- [ ] **Step 1: Write widget test for CreateCleaningPlanScreen**

Buat file `mobile/test/create_cleaning_plan_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/create_cleaning_plan_screen.dart';

void main() {
  testWidgets('CreateCleaningPlanScreen renders all form fields and calculates price', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CreateCleaningPlanScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Buat Paket Langganan Rutin'), findsOneWidget);
    expect(find.byKey(const Key('plan_name_field')), findsOneWidget);
    expect(find.text('Mingguan (Setiap 7 Hari)'), findsOneWidget);
    expect(find.text('Dua Mingguan (Setiap 14 Hari)'), findsOneWidget);
    expect(find.text('Senin'), findsOneWidget);
    expect(find.text('Minggu'), findsOneWidget);

    // Verifikasi tombol submit
    expect(find.text('Aktifkan Paket Langganan'), findsOneWidget);
  });

  testWidgets('CreateCleaningPlanScreen shows validation errors on empty submission', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CreateCleaningPlanScreen(),
    ));
    await tester.pumpAndSettle();

    // Tekan tombol submit tanpa isi data
    final submitButton = find.text('Aktifkan Paket Langganan');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Nama paket wajib diisi (minimal 3 karakter)'), findsOneWidget);
    expect(find.text('Alamat lengkap wajib diisi (minimal 10 karakter)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/create_cleaning_plan_screen_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:mobile/screens/create_cleaning_plan_screen.dart'`.

- [ ] **Step 3: Implement CreateCleaningPlanScreen in mobile/lib/screens/create_cleaning_plan_screen.dart**

Buat layar `CreateCleaningPlanScreen` lengkap dengan:
- Textfield Nama Paket, Alamat, Patokan, Catatan Khusus
- Dropdown Kategori Layanan (Rumah, Kos, Kantor, Pasca Renovasi)
- ChoiceChip Frekuensi (`mingguan`, `dua_mingguan`)
- ChoiceChip 7 Hari (`Senin` s.d. `Minggu` dengan mapping angka `dayOfWeek: 1..7`)
- Dropdown Jam Kedatangan (`08:00` s.d. `17:00`)
- ChoiceChip Durasi (1 Jam s.d. 4 Jam)
- Selector Petugas Favorit (mengambil list dari `ApiService.fetchCleaners()`, dengan opsi default *"Pilih Otomatis oleh Admin"*)
- Card Ringkasan Biaya per Kedatangan dinamis (`Rp 50.000 x duration`)
- Submit method calling `ApiService.createCleaningPlan()` dan navigasi balik dengan snackbar sukses.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/create_cleaning_plan_screen_test.dart`
Expected: PASS (2/2 tests pass).

- [ ] **Step 5: Commit Task 6**

```bash
git add mobile/lib/screens/create_cleaning_plan_screen.dart mobile/test/create_cleaning_plan_screen_test.dart
git commit -m "feat(ui): implement CreateCleaningPlanScreen with form validation and dynamic price calculation"
```

---

### Task 7: Mobile UI - Layar Manajemen Paket Langganan (`CleaningPlansScreen`)

**Files:**
- Create: `mobile/lib/screens/cleaning_plans_screen.dart`
- Test: `mobile/test/cleaning_plans_screen_test.dart`

**Interfaces:**
- Produces: `CleaningPlansScreen` StatefulWidget dengan daftar kartu langganan, tombol jeda/lanjut/batal, tombol trigger sesi berikutnya, FAB buat baru, dan empty state.

- [ ] **Step 1: Write widget test for CleaningPlansScreen**

Buat file `mobile/test/cleaning_plans_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/cleaning_plan_model.dart';
import 'package:mobile/screens/cleaning_plans_screen.dart';

void main() {
  testWidgets('CleaningPlansScreen renders plan cards with schedule info and action buttons', (tester) async {
    final mockPlans = [
      CleaningPlan(
        id: 'plan-001',
        customerId: 'usr-001',
        planName: 'Langganan Bersih Kos Melati',
        serviceCategory: 'kos',
        frequency: 'mingguan',
        dayOfWeek: 1,
        dayName: 'Senin',
        startTime: '09:00',
        duration: 2,
        pricePerSession: 100000,
        address: 'Jl. Kaliurang KM 14.5 No. 4',
        status: 'Aktif',
        nextSessionDate: '2026-10-19',
        totalSessionsCompleted: 3,
        preferredCleaner: CleaningPlanCleanerInfo(
          id: 'cln-001',
          nama: 'Budi Santoso',
          rating: 4.8,
        ),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: CleaningPlansScreen(initialPlans: mockPlans),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cleaning Plan Saya'), findsOneWidget);
    expect(find.text('Langganan Bersih Kos Melati'), findsOneWidget);
    expect(find.textContaining('Setiap Senin, 09:00 WIB (Mingguan)'), findsOneWidget);
    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.text('Jeda'), findsOneWidget);
    expect(find.text('Jadwalkan Sesi Berikutnya'), findsOneWidget);
  });

  testWidgets('CleaningPlansScreen shows empty state illustration when list is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CleaningPlansScreen(initialPlans: []),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Belum Ada Paket Langganan'), findsOneWidget);
    expect(find.text('Mulai Berlangganan'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/cleaning_plans_screen_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:mobile/screens/cleaning_plans_screen.dart'`.

- [ ] **Step 3: Implement CleaningPlansScreen in mobile/lib/screens/cleaning_plans_screen.dart**

Buat layar `CleaningPlansScreen`:
- Mendukung parameter opsional `initialPlans` untuk kemudahan pengetesan widget murni tanpa mock server.
- State list yang memuat data dari `ApiService.fetchCleaningPlans()`.
- Kartu paket dengan badge status (`Aktif` hijau, `Dijeda` oranye, `Dibatalkan` abu-abu).
- Action buttons:
  - Tombol **"Jeda"** / **"Aktifkan"** memicu `ApiService.updateCleaningPlanStatus()`.
  - Tombol **"Jadwalkan Sesi Berikutnya"** memicu `ApiService.generateNextCleaningPlanSession()` dan menampilkan snackbar dengan nomor sesi baru yang terbuat.
  - Menu titik tiga untuk **"Batalkan Langganan"** dengan AlertDialog konfirmasi.
- FAB `+ Buat Paket Baru` yang membuka `CreateCleaningPlanScreen`.
- Pull-to-refresh (`RefreshIndicator`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/cleaning_plans_screen_test.dart`
Expected: PASS (2/2 tests pass).

- [ ] **Step 5: Commit Task 7**

```bash
git add mobile/lib/screens/cleaning_plans_screen.dart mobile/test/cleaning_plans_screen_test.dart
git commit -m "feat(ui): implement CleaningPlansScreen with interactive plan cards and action buttons"
```

---

### Task 8: Mobile UI - Integrasi Titik Masuk & Badge Pelacakan

**Files:**
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/screens/order_tracking_screen.dart`
- Create: `mobile/test/cleaning_plan_entry_point_test.dart`

**Interfaces:**
- Produces: Banner di `HomeScreen`, Tab di `CustomerOrdersScreen`, dan badge langganan di `OrderTrackingScreen`.

- [ ] **Step 1: Write integration entry point test**

Buat file `mobile/test/cleaning_plan_entry_point_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/cleaning_plans_screen.dart';

void main() {
  testWidgets('HomeScreen renders Cleaning Plan banner and navigates to CleaningPlansScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));
    await tester.pumpAndSettle();

    final bannerFinder = find.byKey(const Key('banner_cleaning_plan'));
    expect(bannerFinder, findsOneWidget);

    await tester.tap(bannerFinder);
    await tester.pumpAndSettle();

    expect(find.byType(CleaningPlansScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/cleaning_plan_entry_point_test.dart`
Expected: FAIL with banner key not found.

- [ ] **Step 3: Update HomeScreen in main.dart & OrderTrackingScreen**

1. Di `mobile/lib/main.dart`:
   - Tambahkan banner kartu promosi dengan key `'banner_cleaning_plan'`: *"Langganan Rutin (Cleaning Plan) — Rumah Selalu Bersih Tiap Minggu"* dengan tombol *"Kelola Paket"*.
   - Saat diklik, lakukan `Navigator.push(context, MaterialPageRoute(builder: (_) => const CleaningPlansScreen()))`.
2. Di `mobile/lib/screens/order_tracking_screen.dart`:
   - Jika `order.cleaningPlanId != null`:
     - Tampilkan container badge di atas status stepper:
       `✨ Pesanan dari Paket Langganan • Sesi #${order.sessionNumber ?? 1}`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/cleaning_plan_entry_point_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit Task 8**

```bash
git add mobile/lib/main.dart mobile/lib/screens/order_tracking_screen.dart mobile/test/cleaning_plan_entry_point_test.dart
git commit -m "feat(ui): connect HomeScreen banner and OrderTrackingScreen badge to Cleaning Plan"
```

---

### Task 9: Full System Verification, Regression Testing, Documentation, & Push

**Files:**
- Modify: `laporan-skripsi-resikin/LOGBOOK-HARIAN.md`
- Modify: `laporan-skripsi-resikin/PROGRESS-PROJECT.md`
- Modify: `laporan-skripsi-resikin/PROGRESS-SKRIPSI.md`

- [ ] **Step 1: Run full Backend test suite**

Run: `cd backend && npm test`
Expected: 100% PASS (All test suites pass, 0 failures).

- [ ] **Step 2: Run full Mobile test suite**

Run: `cd mobile && flutter test`
Expected: 100% PASS (All widget & model tests pass, 0 failures).

- [ ] **Step 3: Run Flutter static analysis**

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 4: Update skripsi logbook & progress documentation**

Update `LOGBOOK-HARIAN.md`, `PROGRESS-PROJECT.md`, dan `PROGRESS-SKRIPSI.md` dengan deliverable resmi FR-12 Cleaning Plan V2.0.

- [ ] **Step 5: Final Commit & Push**

```bash
git add laporan-skripsi-resikin/LOGBOOK-HARIAN.md laporan-skripsi-resikin/PROGRESS-PROJECT.md laporan-skripsi-resikin/PROGRESS-SKRIPSI.md
git commit -m "docs(skripsi): update logbook and progress tracker for completed Cleaning Plan (FR-12) V2.0"
git push origin main
```
