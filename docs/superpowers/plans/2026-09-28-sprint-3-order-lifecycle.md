# Sprint 3: Order Lifecycle, Tracking Stepper, and Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengimplementasikan siklus hidup pesanan 7 status sekuensial mutlak, validasi penugasan petugas anti-double booking (+ buffer 30 menit), penggantian petugas ber-audit, pembatalan pesanan berbasis peran, layar Flutter Pelacakan Pesanan (Screen 4 Stitch), dan panel kontrol simulasi operasional terisolasi untuk kemudahan pengujian di perangkat HP.

**Architecture:** Arsitektur memadukan Express REST API server-authoritative (`backend/routes/orders.js`) dengan validasi hak akses dan status sekuensial mutlak, serta aplikasi Flutter (`mobile/lib/screens/order_tracking_screen.dart`) yang mengadopsi rancangan Stitch Screen 4 dengan komponen *OperationalSimulationSheet* terisolasi yang dapat dimatikan via flag konstanta tanpa merombak logika backend.

**Tech Stack:** Node.js (ES Module), Express.js, Supabase in-memory fallback, Flutter (Dart), Flutter Test, Jest/Node Test.

**Spec:** [docs/superpowers/specs/2026-09-28-sprint-3-order-lifecycle-design.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/superpowers/specs/2026-09-28-sprint-3-order-lifecycle-design.md)

## Global Constraints
- Syntactic Standard: Node.js ES Modules (`import`/`export`), Dart 3 with sound null safety.
- Envelope Response: `{ "success": true, "message": "...", "data": { ... } }` dan `{ "success": false, "message": "...", "error": "..." }`.
- Status Lifecycle: 7 sequential stages: `Menunggu Konfirmasi` -> `Dikonfirmasi` -> `Petugas Ditugaskan` -> `Menuju Lokasi` -> `Tiba di Lokasi` -> `Sedang Dikerjakan` -> `Selesai` + `Dibatalkan` (terminal state). No status skipping.
- Anti-Double Booking: Same date, cleaner busy window `[start_time, end_time + 30m]` -> `409 Conflict`.
- RBAC Cancellation: Customer cannot cancel once in field stages (`Menuju Lokasi`, etc.); Admin can cancel anytime before `Selesai`.
- Clean Code: Minimal diff, no hardcoded secrets, test coverage before code commits.

---

### Task 1: Backend Sequential Status Progression (`PATCH /api/orders/:id/status`)

**Files:**
- Modify: `backend/routes/orders.js`
- Test: `backend/test/orders_lifecycle.test.js`

**Interfaces:**
- Consumes: `inMemoryStore.orders`, `inMemoryStore.status_logs`
- Produces: `PATCH /api/orders/:id/status` endpoint:
  - Input: `{ status_baru: string, role?: string }`
  - Output: `{ success: true, message: string, data: { id, status_pekerjaan, started_at? } }`

- [ ] **Step 1: Write the failing test**

Buat file `backend/test/orders_lifecycle.test.js`:
```javascript
import { describe, it, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import ordersRouter from '../routes/orders.js';
import { inMemoryStore } from '../lib/supabase.js';

const app = express();
app.use(express.json());
app.use('/api/orders', ordersRouter);

describe('Sprint 3: Backend Order Lifecycle & Transitions', () => {
  let sampleOrder;

  beforeEach(() => {
    inMemoryStore.orders = [];
    inMemoryStore.status_logs = [];
    sampleOrder = {
      id: 'ord-test-101',
      order_code: 'RSK-20260928-101',
      customer_id: 'usr-cust-001',
      service_id: 'srv-001',
      cleaner_id: null,
      tanggal_layanan: '2026-09-29',
      start_time: '09:00',
      end_time: '11:00',
      duration: 2,
      status_pembayaran: 'Belum Bayar',
      status_pekerjaan: 'Menunggu Konfirmasi',
      payment_timestamp: null,
      created_at: new Date().toISOString()
    };
    inMemoryStore.orders.push(sampleOrder);
  });

  it('gagal konfirmasi jika status_pembayaran masih Belum Bayar', async () => {
    const res = await fetch('http://localhost:3000/api/orders/ord-test-101/status', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status_baru: 'Dikonfirmasi', role: 'admin' })
    });
    // Diuji via router logic / supertest / handler
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend; node --test test/orders_lifecycle.test.js`  
Expected: FAIL (endpoint `PATCH /api/orders/:id/status` belum ada).

- [ ] **Step 3: Write minimal implementation**

Di `backend/routes/orders.js`, tambahkan route `PATCH /:id/status`:
```javascript
router.patch('/:id/status', (req, res) => {
  const { id } = req.params;
  const { status_baru, role } = req.body;
  const order = inMemoryStore.orders.find(o => o.id === id);

  if (!order) {
    return res.status(404).json({ success: false, message: 'Pesanan tidak ditemukan', error: 'ORDER_NOT_FOUND' });
  }

  const validTransitions = {
    'Menunggu Konfirmasi': ['Dikonfirmasi'],
    'Dikonfirmasi': ['Petugas Ditugaskan'],
    'Petugas Ditugaskan': ['Menuju Lokasi'],
    'Menuju Lokasi': ['Tiba di Lokasi'],
    'Tiba di Lokasi': ['Sedang Dikerjakan'],
    'Sedang Dikerjakan': [] // Selesai hanya via Quality Report
  };

  const allowedNext = validTransitions[order.status_pekerjaan] || [];
  if (!allowedNext.includes(status_baru)) {
    return res.status(400).json({
      success: false,
      message: `Transisi status tidak valid dari ${order.status_pekerjaan} ke ${status_baru}`,
      error: 'INVALID_STATUS_TRANSITION'
    });
  }

  if (status_baru === 'Dikonfirmasi') {
    if (order.status_pembayaran !== 'Sudah Bayar') {
      return res.status(400).json({
        success: false,
        message: 'Pesanan belum dibayar. Konfirmasi hanya diizinkan untuk pesanan lunas.',
        error: 'ORDER_NOT_PAID_YET'
      });
    }
  }

  const prevStatus = order.status_pekerjaan;
  order.status_pekerjaan = status_baru;
  if (status_baru === 'Sedang Dikerjakan') {
    order.started_at = new Date().toISOString();
  }

  inMemoryStore.status_logs.push({
    id: crypto.randomUUID(),
    order_id: order.id,
    status_sebelumnya: prevStatus,
    status_baru: status_baru,
    diubah_oleh: role || 'system',
    catatan: `Status pekerjaan diperbarui menjadi ${status_baru}`,
    created_at: new Date().toISOString()
  });

  return res.status(200).json({
    success: true,
    message: 'Status pekerjaan berhasil diperbarui',
    data: {
      id: order.id,
      status_pekerjaan: order.status_pekerjaan,
      started_at: order.started_at || null
    }
  });
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend; node --test test/orders_lifecycle.test.js`  
Expected: PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add backend/routes/orders.js backend/test/orders_lifecycle.test.js
git commit -m "feat(backend): implement sequential order status progression"
```

---

### Task 2: Backend Hybrid Assignment & Reassignment (`POST /api/orders/:id/assign` & `reassign`)

**Files:**
- Modify: `backend/routes/orders.js`
- Test: `backend/test/orders_lifecycle.test.js`

**Interfaces:**
- Consumes: `inMemoryStore.cleaners`, `inMemoryStore.orders`, helper bentrok jadwal
- Produces: `POST /api/orders/:id/assign` dan `POST /api/orders/:id/reassign`

- [ ] **Step 1: Write the failing test**

Di `backend/test/orders_lifecycle.test.js`, tambahkan suite uji:
1. Menolak penugasan jika status pesanan masih `Menunggu Konfirmasi` (`400 Bad Request`).
2. Menolak penugasan jika petugas jadwalnya bentrok (+ buffer 30 menit) (`409 Conflict`).
3. Berhasil menugaskan petugas jika jadwal bebas bentrok $\rightarrow$ status berubah ke `Petugas Ditugaskan`.
4. Berhasil mengganti petugas (*reassign*) saat status `Petugas Ditugaskan` dan mencatat audit log dengan format: `REASSIGN_CLEANER: dari {old} ke {new} - Alasan: {alasan}`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend; node --test test/orders_lifecycle.test.js`  
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Di `backend/routes/orders.js`:
- Buat fungsi pembantu helper interval tumpang tindih: `isTimeOverlapping(startA, endA, startB, endB, bufferMinutes = 30)`.
- Implementasikan endpoint `POST /:id/assign`.
- Implementasikan endpoint `POST /:id/reassign`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend; node --test test/orders_lifecycle.test.js`  
Expected: PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add backend/routes/orders.js backend/test/orders_lifecycle.test.js
git commit -m "feat(backend): implement hybrid assignment and reassign with conflict detection"
```

---

### Task 3: Backend Role-Based Cancellation (`POST /api/orders/:id/cancel`)

**Files:**
- Modify: `backend/routes/orders.js`
- Test: `backend/test/orders_lifecycle.test.js`

**Interfaces:**
- Consumes: `inMemoryStore.orders`, `inMemoryStore.cleaners`
- Produces: `POST /api/orders/:id/cancel`:
  - Input: `{ cancellation_reason: string, role: 'customer' | 'admin' }`

- [ ] **Step 1: Write the failing test**

Di `backend/test/orders_lifecycle.test.js`, tambahkan suite uji:
1. Menolak pembatalan jika alasan < 5 karakter (`400 Bad Request`).
2. Pelanggan ditolak membatalkan jika status sudah `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan` (`403 Forbidden`).
3. Pelanggan diizinkan membatalkan jika status `Dikonfirmasi` atau `Petugas Ditugaskan`.
4. Admin diizinkan membatalkan darurat saat status `Sedang Dikerjakan`.
5. Status berubah menjadi `Dibatalkan` dan status petugas dipulihkan menjadi `Aktif`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend; node --test test/orders_lifecycle.test.js`  
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Di `backend/routes/orders.js`, implementasikan endpoint `POST /:id/cancel`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend; npm test` (jalankan seluruh test backend).  
Expected: Seluruh test suite (lama + baru) PASS 100%.

- [ ] **Step 5: Commit**

Run:
```bash
git add backend/routes/orders.js backend/test/orders_lifecycle.test.js
git commit -m "feat(backend): implement role-based order cancellation with audit logs"
```

---

### Task 4: Mobile Data Models & API Service Extensions

**Files:**
- Modify: `mobile/lib/models/order_model.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Test: `mobile/test/api_service_lifecycle_test.dart`

**Interfaces:**
- Produces:
  - `OrderModel` dengan atribut: `cleaner`, `startedAt`, `cancellationReason`, `cancelledBy`, `cancelledAt`.
  - `ApiService.updateOrderStatus(orderId, status, {role})`
  - `ApiService.assignCleaner(orderId, cleanerId, {role})`
  - `ApiService.cancelOrder(orderId, reason, {role})`

- [ ] **Step 1: Write the failing test**

Buat test `mobile/test/api_service_lifecycle_test.dart` untuk memastikan parsing model `OrderModel` dan method-method baru di `ApiService` memiliki signature yang tepat dan mengembalikan hasil sesuai kontrak JSON.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile; flutter test test/api_service_lifecycle_test.dart`  
Expected: FAIL (missing fields / methods).

- [ ] **Step 3: Write minimal implementation**

Perbarui `mobile/lib/models/order_model.dart` dan `mobile/lib/services/api_service.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile; flutter test test/api_service_lifecycle_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add mobile/lib/models/order_model.dart mobile/lib/services/api_service.dart mobile/test/api_service_lifecycle_test.dart
git commit -m "feat(mobile): extend OrderModel and ApiService for order lifecycle operations"
```

---

### Task 5: Mobile Screen 4 Implementation (`OrderTrackingScreen`)

**Files:**
- Create: `mobile/lib/screens/order_tracking_screen.dart`
- Modify: `mobile/lib/constants.dart` (tambahkan flag `kEnableOperationalSimulation = true`)
- Test: `mobile/test/order_tracking_screen_test.dart`

**Interfaces:**
- Produces: `OrderTrackingScreen(orderId: String)`
- Features:
  - 7-Stage visual stepper
  - Live progress ambient gradient card
  - Active cleaner card with name, star rating, phone call launcher
  - Cancel order button with reason prompt dialog

- [ ] **Step 1: Write the failing test**

Buat `mobile/test/order_tracking_screen_test.dart`:
- Render `OrderTrackingScreen` dengan mock order.
- Verifikasi stepper menampilkan 7 tahapan dengan indikator aktif yang sesuai.
- Verifikasi kartu profil petugas merender nama dan rating.
- Verifikasi tombol batalkan muncul saat status `Dikonfirmasi`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile; flutter test test/order_tracking_screen_test.dart`  
Expected: FAIL (`OrderTrackingScreen` does not exist).

- [ ] **Step 3: Write minimal implementation**

Bangun `OrderTrackingScreen` di `mobile/lib/screens/order_tracking_screen.dart` mengadopsi struktur HTML Screen 4 Stitch.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile; flutter test test/order_tracking_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add mobile/lib/screens/order_tracking_screen.dart mobile/lib/constants.dart mobile/test/order_tracking_screen_test.dart
git commit -m "feat(mobile): implement Screen 4 OrderTrackingScreen with 7-stage visual stepper"
```

---

### Task 6: Modular Operational Simulation Sheet & Wire Navigation Flow

**Files:**
- Create: `mobile/lib/widgets/operational_simulation_sheet.dart`
- Modify: `mobile/lib/screens/order_tracking_screen.dart`
- Modify: `mobile/lib/screens/payment_screen.dart`
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/order_tracking_screen_test.dart`

**Interfaces:**
- Produces:
  - `OperationalSimulationSheet` bottom sheet widget.
  - Floating action button / AppBar action di `OrderTrackingScreen` memicu sheet simulasi saat `kEnableOperationalSimulation == true`.
  - Navigasi `PaymentScreen` setelah pembayaran sukses $\rightarrow$ `OrderTrackingScreen`.
  - Banner pesanan aktif di `HomeScreen` $\rightarrow$ klik buka `OrderTrackingScreen`.

- [ ] **Step 1: Write the failing test**

Update `mobile/test/order_tracking_screen_test.dart`:
- Verifikasi saat `kEnableOperationalSimulation` aktif, tombol Simulasi Operasional dapat ditekan dan menampilkan bottom sheet aksi.
- Verifikasi aksi memajukan status memicu panggilan `ApiService.updateOrderStatus`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile; flutter test test/order_tracking_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Buat `mobile/lib/widgets/operational_simulation_sheet.dart` dan pasang navigasi di `payment_screen.dart` serta `main.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile; flutter test` dan `cd mobile; flutter analyze`.  
Expected: 0 issues, all tests PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add mobile/lib/widgets/operational_simulation_sheet.dart mobile/lib/screens/order_tracking_screen.dart mobile/lib/screens/payment_screen.dart mobile/lib/main.dart mobile/test/order_tracking_screen_test.dart
git commit -m "feat(mobile): add OperationalSimulationSheet and wire tracking navigation"
```

---

### Task 7: Full System Verification & Regression Run

**Files:**
- Backend tests
- Flutter analyze and test

- [ ] **Step 1: Run complete backend test suite**

Run: `cd backend; npm test`  
Expected: 100% tests PASS without error.

- [ ] **Step 2: Run complete Flutter analyze and test**

Run: `cd mobile; flutter analyze`  
Expected: `No issues found!`.  
Run: `cd mobile; flutter test`  
Expected: All tests pass.

- [ ] **Step 3: Verification Report and Clean Git Status**

Run: `git status`
Expected: Working tree clean on branch `feat/sprint-3-order-lifecycle`.
