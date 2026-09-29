# Sprint 4: Digital Quality Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengimplementasikan gerbang validasi laporan mutu (*Quality Report Digital — FR-10*) berbasis private Supabase Storage, token temporary Signed URL 30 menit, checklist 100% per kategori layanan, invarian konsistensi timestamp server, status lockout gate ke `Selesai`, form unggah foto Before/After di Flutter, dan layar penuh peninjauan laporan mutu bagi Pelanggan (*Dedicated Full-Screen: `QualityReportScreen`*).

**Architecture:** Arsitektur backend Express modular (`backend/routes/quality-reports.js`) menerapkan 9-tahap pipeline validasi server-authoritative yang memutasi pesanan ke status `Selesai`, memulihkan status petugas ke `Aktif`, dan mencatat audit log. Klien Flutter (`mobile/`) mengunggah berkas terkompresi langsung ke Supabase Storage private bucket `quality-reports` pada path `orders/{order_id}/...`, menyediakan dialog form dinamis berbasis kategori layanan, dan menyajikan layar laporan komparasi sebelum/sesudah dengan badge penguncian *read-only*.

**Tech Stack:**
- Backend: Node.js (ES Module), Express.js, Supabase Client (`@supabase/supabase-js`), Node Test Runner (`node:test`, `node:assert/strict`).
- Mobile: Flutter / Dart (v3.13+), Supabase Flutter SDK (`supabase_flutter`), Image Picker (`image_picker`), Cupertino Icons, Google Fonts, Http.

**Spec:** [`docs/superpowers/specs/2026-09-29-sprint-4-quality-report-design.md`](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/superpowers/specs/2026-09-29-sprint-4-quality-report-design.md)

## Global Constraints
- Target kelulusan test suite adalah 100% tanpa kompromi (Backend 8 test suite + Mobile widget tests).
- Backend respons wajib mematuhi amplop standar: `{ "success": true/false, "message": "...", "data": ... }`.
- Transisi status ke `Selesai` **hanya diizinkan** melalui `POST /api/quality-reports`.
- Semua area checklist pada template layanan wajib bernilai `completed: true`. Validasi parsial ditolak `400 Bad Request` (`CHECKLIST_AREAS_INCOMPLETE`).
- Server timestamp wajib memenuhi invarian $\text{started\_at} \le \text{completed\_at} \le \text{submitted\_at}$ dan $\text{completed\_at} \le \text{NOW()}$.
- Signed URL berdurasi tepat 1800 detik (30 menit) dan hanya dapat diakses oleh Pelanggan pemilik, Petugas terkait, dan Admin.

---

### Task 1: Backend Checklist Templates & Data Scaffolding

**Files:**
- Create: `backend/lib/checklist-templates.js`
- Modify: `backend/lib/supabase.js:140-150`
- Test: `backend/test/quality_reports.test.js`

**Interfaces:**
- Produces: `CHECKLIST_TEMPLATES` mapping per kategori layanan (`rumah`, `kos`, `kantor`, `renovasi`).
- Consumes: `inMemoryStore.quality_reports` dari `backend/lib/supabase.js`.

- [ ] **Step 1: Write the failing test for checklist templates**

```javascript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/quality_reports.test.js`  
Expected: FAIL with "Cannot find module '../lib/checklist-templates.js'"

- [ ] **Step 3: Write minimal implementation**

```javascript
// backend/lib/checklist-templates.js
export const CHECKLIST_TEMPLATES = {
  rumah: [
    'Ruang Tamu',
    'Kamar Tidur',
    'Dapur',
    'Kamar Mandi',
    'Area Tambahan Sesuai Paket'
  ],
  kos: [
    'Kamar Tidur / Utama',
    'Kamar Mandi',
    'Area yang Termasuk Paket'
  ],
  kantor: [
    'Ruang Kerja',
    'Area Umum / Koridor',
    'Toilet Kantor',
    'Pantry / Dapur Bersih'
  ],
  renovasi: [
    'Area Utama Pekerjaan',
    'Pembersihan Lantai & Sudut Ruangan',
    'Pembersihan Debu & Sisa Material Semen/Cat',
    'Ruangan yang Termasuk Paket'
  ]
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/quality_reports.test.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/lib/checklist-templates.js backend/test/quality_reports.test.js
git commit -m "feat(backend): add quality report checklist templates per service category"
```

---

### Task 2: Backend 9-Stage Validation Pipeline & `POST /api/quality-reports`

**Files:**
- Modify: `backend/routes/quality-reports.js:1-40`
- Test: `backend/test/quality_reports.test.js`

**Interfaces:**
- Produces: `POST /api/quality-reports` handler.
- Consumes: `inMemoryStore.orders`, `inMemoryStore.cleaners`, `inMemoryStore.quality_reports`, `CHECKLIST_TEMPLATES`.

- [ ] **Step 1: Write failing tests for 9-stage validation pipeline**

Tambahkan pengujian pada `backend/test/quality_reports.test.js`:
- Submit sukses memutasi order status ke `Selesai`, cleaner status ke `Aktif`, dan `total_pekerjaan` +1.
- Menolak dengan `CHECKLIST_AREAS_INCOMPLETE` jika ada area checklist yang hilang atau `completed: false`.
- Menolak dengan `INVALID_TIMESTAMPS` jika `started_at > completed_at` atau `completed_at` di masa depan.
- Menolak dengan `ORDER_NOT_IN_PROGRESS` jika status pesanan bukan `Sedang Dikerjakan`.
- Menolak dengan `INVALID_STORAGE_PATH` jika path foto tidak berawalan `orders/{order_id}/`.

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/quality_reports.test.js`  
Expected: FAIL (endpoint belum diimplementasikan / masih return stub).

- [ ] **Step 3: Implement `POST /api/quality-reports`**

Buat logika lengkap di `backend/routes/quality-reports.js`:
- Verifikasi keberadaan order di `inMemoryStore.orders`.
- Cek status order: wajib `Sedang Dikerjakan`.
- Cari service terkait untuk mendapatkan `service.kategori`.
- Validasi checklist area terhadap `CHECKLIST_TEMPLATES[service.kategori]`. Pastikan seluruh area ada dan `item.completed === true`.
- Validasi timestamp server:
  - `started_at = order.started_at || order.created_at`.
  - `completed_at = new Date(body.completed_at)`.
  - `now = new Date()`.
  - Pastikan `started_at <= completed_at <= now`.
- Validasi path foto:
  - `foto_before_path` dan `foto_after_path` harus diawali dengan `orders/${order.id}/`.
- Simpan rekaman baru ke `inMemoryStore.quality_reports`.
- Perbarui `order.status_pekerjaan = 'Selesai'`.
- Tambah catatan audit ke `inMemoryStore.status_logs`.
- Cari petugas pada `order.cleaner_id`: set `status_operasional = 'Aktif'`, tambah `total_pekerjaan` +1.
- Return HTTP 201 Created dengan amplop standar.

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/quality_reports.test.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/routes/quality-reports.js backend/test/quality_reports.test.js
git commit -m "feat(backend): implement POST /api/quality-reports with 9-stage validation pipeline"
```

---

### Task 3: Backend Temporary Signed URL & `GET /api/quality-reports/:order_id`

**Files:**
- Modify: `backend/routes/quality-reports.js:40-100`
- Test: `backend/test/quality_reports.test.js`

**Interfaces:**
- Produces: `GET /api/quality-reports/:order_id` handler.
- Consumes: `inMemoryStore.quality_reports`, Supabase Storage Signed URL generator (dengan fallback adaptif).

- [ ] **Step 1: Write failing tests for inspection and RBAC**

Tambahkan pengujian:
- Customer pemilik order, Cleaner penanggung jawab, dan Admin berhasil menerima data laporan dengan `foto_before_signed_url` dan `foto_after_signed_url`.
- Pengguna lain ditolak dengan status HTTP `403 Forbidden` (`FORBIDDEN_REPORT_ACCESS`).
- Order yang belum memiliki laporan mutu mengembalikan `404 Not Found` (`REPORT_NOT_FOUND`).

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/quality_reports.test.js`  
Expected: FAIL

- [ ] **Step 3: Implement `GET /api/quality-reports/:order_id`**

Di `backend/routes/quality-reports.js`:
- Temukan order berdasarkan `req.params.order_id`.
- Validasi otorisasi:
  - Ambil `user_id = req.headers['x-user-id']` atau query `user_id`, dan `role = req.headers['x-user-role']` atau query `role`.
  - Jika bukan customer order, bukan cleaner order, dan bukan admin -> tolak `403 Forbidden`.
- Cari laporan di `inMemoryStore.quality_reports`.
- Hasilkan signed URL (durasi 1800 detik):
  - Jika Supabase live client aktif: panggil `supabase.storage.from('quality-reports').createSignedUrl(path, 1800)`.
  - Jika dalam mock/test mode: buat URL signed terformat (`https://storage.supabase.co/storage/v1/object/sign/quality-reports/${path}?token=mock-token-${Date.now()}`).
- Return HTTP 200 OK dengan data laporan lengkap.

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/quality_reports.test.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/routes/quality-reports.js backend/test/quality_reports.test.js
git commit -m "feat(backend): implement GET /api/quality-reports/:order_id with signed URL and RBAC"
```

---

### Task 4: Backend Status Lockout Gate di `PATCH /api/orders/:id/status`

**Files:**
- Modify: `backend/routes/orders.js:330-360`
- Test: `backend/test/orders_lifecycle.test.js`

**Interfaces:**
- Produces: Blokade mutasi langsung ke `Selesai` via `PATCH /api/orders/:id/status`.

- [ ] **Step 1: Write failing test in `backend/test/orders_lifecycle.test.js`**

```javascript
test('PATCH /api/orders/:id/status menolak transisi langsung ke Selesai tanpa Quality Report', async () => {
  // Setup order pada status Sedang Dikerjakan
  const res = await request(app)
    .patch(`/api/orders/${orderInProgress.id}/status`)
    .send({ status_baru: 'Selesai', role: 'cleaner' });
  
  assert.strictEqual(res.status, 400);
  assert.strictEqual(res.body.error, 'QUALITY_REPORT_REQUIRED');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/orders_lifecycle.test.js`  
Expected: FAIL (masih return `INVALID_STATUS_TRANSITION` bukan `QUALITY_REPORT_REQUIRED`).

- [ ] **Step 3: Update `backend/routes/orders.js`**

Di handler `PATCH /api/orders/:id/status`:
```javascript
if (status_baru === 'Selesai') {
  return res.status(400).json({
    success: false,
    message: 'Transisi ke status Selesai wajib melalui pengiriman Quality Report pada POST /api/quality-reports',
    error: 'QUALITY_REPORT_REQUIRED'
  });
}
```

- [ ] **Step 4: Run all backend tests to verify it passes**

Run: `cd backend && npm test`  
Expected: All 9 test suites pass (100%).

- [ ] **Step 5: Commit**

```bash
git add backend/routes/orders.js backend/test/orders_lifecycle.test.js
git commit -m "feat(backend): enforce mandatory gate lockout to status Selesai without quality report"
```

---

### Task 5: Mobile Dependency & Quality Report Data Model

**Files:**
- Modify: `mobile/pubspec.yaml:35-42`
- Create: `mobile/lib/models/quality_report_model.dart`
- Test: `mobile/test/quality_report_model_test.dart`

**Interfaces:**
- Produces: `QualityReportModel`, `ChecklistItemModel`.

- [ ] **Step 1: Add `image_picker` dependency to `mobile/pubspec.yaml`**

Tambahkan `image_picker: ^1.1.2` pada dependencies di `mobile/pubspec.yaml`, lalu jalankan `flutter pub get`.

- [ ] **Step 2: Write failing unit test for `QualityReportModel`**

```dart
// mobile/test/quality_report_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in/models/quality_report_model.dart';

void main() {
  test('QualityReportModel parsing dari JSON harus valid', () {
    final json = {
      'id': 'rep-001',
      'order_id': 'ord-001',
      'cleaner_nama': 'Candra Pratama',
      'checklist_area': [
        {'area': 'Ruang Tamu', 'completed': true},
        {'area': 'Kamar Mandi', 'completed': true}
      ],
      'catatan_petugas': 'Bersih rapi',
      'foto_before_signed_url': 'https://supabase.../before.webp',
      'foto_after_signed_url': 'https://supabase.../after.webp',
      'signed_url_expires_in': 1800,
      'started_at': '2026-09-29T08:00:00.000Z',
      'completed_at': '2026-09-29T10:00:00.000Z',
      'submitted_at': '2026-09-29T10:02:00.000Z',
    };

    final report = QualityReportModel.fromJson(json);
    expect(report.id, 'rep-001');
    expect(report.orderId, 'ord-001');
    expect(report.cleanerNama, 'Candra Pratama');
    expect(report.checklistArea.length, 2);
    expect(report.checklistArea.first.area, 'Ruang Tamu');
    expect(report.checklistArea.first.completed, true);
    expect(report.isLocked, true);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd mobile && flutter test test/quality_report_model_test.dart`  
Expected: FAIL

- [ ] **Step 4: Implement `QualityReportModel`**

Buat `mobile/lib/models/quality_report_model.dart` dengan class `ChecklistItemModel` dan `QualityReportModel`, mendukung serialisasi `fromJson` dan `toJson`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd mobile && flutter test test/quality_report_model_test.dart`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/models/quality_report_model.dart mobile/test/quality_report_model_test.dart
git commit -m "feat(mobile): add image_picker dependency and QualityReportModel with unit test"
```

---

### Task 6: Mobile Quality Report API Service

**Files:**
- Create: `mobile/lib/services/quality_report_service.dart`
- Test: `mobile/test/quality_report_service_test.dart`

**Interfaces:**
- Produces: `QualityReportService` (`submitReport`, `fetchReport`, `getChecklistTemplateForCategory`).
- Consumes: `ApiService`, `AppConfig.baseUrl`.

- [ ] **Step 1: Write unit test for `QualityReportService`**

```dart
// mobile/test/quality_report_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in/services/quality_report_service.dart';

void main() {
  test('getChecklistTemplateForCategory mengembalikan daftar area yang tepat', () {
    final service = QualityReportService();
    final rumahAreas = service.getChecklistTemplateForCategory('rumah');
    expect(rumahAreas.length, 5);
    expect(rumahAreas.contains('Ruang Tamu'), true);

    final kosAreas = service.getChecklistTemplateForCategory('kos');
    expect(kosAreas.length, 3);
    expect(kosAreas.contains('Kamar Tidur / Utama'), true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/quality_report_service_test.dart`  
Expected: FAIL

- [ ] **Step 3: Implement `QualityReportService`**

Buat `mobile/lib/services/quality_report_service.dart`:
- Metode template checklist per kategori.
- Metode `submitReport`: memanggil `POST /api/quality-reports`.
- Metode `fetchReport`: memanggil `GET /api/quality-reports/:orderId`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/quality_report_service_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/quality_report_service.dart mobile/test/quality_report_service_test.dart
git commit -m "feat(mobile): implement QualityReportService with category template helper"
```

---

### Task 7: Mobile Quality Report Submission Form Dialog/Sheet

**Files:**
- Create: `mobile/lib/widgets/quality_report_form_sheet.dart`
- Test: `mobile/test/quality_report_form_sheet_test.dart`

**Interfaces:**
- Produces: `QualityReportFormSheet` widget.
- Consumes: `QualityReportService`, `OrderModel`.

- [ ] **Step 1: Write widget test for form sheet**

Verifikasi:
- Checklist area tampil sesuai kategori order.
- Terdapat tombol pemilih foto Before & After.
- Tombol Kirim dinonaktifkan (*disabled*) jika foto belum terisi atau checklist belum tercentang semua.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/quality_report_form_sheet_test.dart`  
Expected: FAIL

- [ ] **Step 3: Implement `QualityReportFormSheet`**

Komponen Modal Bottom Sheet:
- Header: *"Pengisian Laporan Mutu Pekerjaan"*.
- Checklist builder dengan checkbox interaktif untuk setiap item template.
- Dua kotak pemilih foto (`ImageSource.camera` / `ImageSource.gallery`) via `image_picker`. Menampilkan thumbnail setelah foto terpilih.
- Input catatan teks (*catatan petugas*).
- Tombol kirim laporan dengan animasi loading dan validasi lengkap.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/quality_report_form_sheet_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/quality_report_form_sheet.dart mobile/test/quality_report_form_sheet_test.dart
git commit -m "feat(mobile): implement QualityReportFormSheet with dynamic checklist and photo picker"
```

---

### Task 8: Mobile Dedicated Full-Screen Viewer (`QualityReportScreen`)

**Files:**
- Create: `mobile/lib/screens/quality_report_screen.dart`
- Test: `mobile/test/quality_report_screen_test.dart`

**Interfaces:**
- Produces: `QualityReportScreen` (Dedicated Full-Screen untuk Pelanggan).
- Consumes: `QualityReportService`, `OrderModel`.

- [ ] **Step 1: Write widget test for `QualityReportScreen`**

Verifikasi:
- Menampilkan badge *"Laporan Mutu Terverifikasi (Read-Only Lock)"*.
- Menampilkan foto Sebelum dan Sesudah dengan widget komparasi.
- Menampilkan seluruh checklist area dengan centang hijau tebal.
- Menampilkan kartu audit timestamp (`started_at`, `completed_at`, `submitted_at`).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/quality_report_screen_test.dart`  
Expected: FAIL

- [ ] **Step 3: Implement `QualityReportScreen`**

Buat `mobile/lib/screens/quality_report_screen.dart`:
- Scaffold lengkap dengan AppBar: *"Laporan Hasil Kerja"*.
- State management: memuat data via `QualityReportService.fetchReport(orderId)`.
- Komparasi foto Sebelum/Sesudah interaktif (tab switcher atau kartu berdampingan).
- Bagian Checklist Area dengan ikon verifikasi hijau.
- Bagian Catatan Petugas dan Profil Petugas.
- Bagian Audit Trail Waktu (3 timestamp presisi).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/quality_report_screen_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/quality_report_screen.dart mobile/test/quality_report_screen_test.dart
git commit -m "feat(mobile): implement dedicated QualityReportScreen for customer review"
```

---

### Task 9: Mobile UI Integration (`OrderTrackingScreen` & `OperationalSimulationSheet`)

**Files:**
- Modify: `mobile/lib/screens/order_tracking_screen.dart:180-260`
- Modify: `mobile/lib/widgets/operational_simulation_sheet.dart:80-140`
- Test: `mobile/test/order_tracking_screen_test.dart`

**Interfaces:**
- Integrasi tombol *"Lihat Laporan Mutu"* pada `OrderTrackingScreen` saat status `Selesai`.
- Integrasi tombol *"Selesaikan Pekerjaan"* pada `OperationalSimulationSheet` untuk membuka `QualityReportFormSheet`.

- [ ] **Step 1: Write widget test for integration points**

Tambahkan pengujian:
- Saat `order.status_pekerjaan == 'Selesai'`, kartu *"Lihat Laporan Mutu"* tampil di `OrderTrackingScreen`.
- Saat mengklik kartu tersebut, layar bernavigasi ke `QualityReportScreen`.
- Pada `OperationalSimulationSheet`, tombol *"Selesaikan Pekerjaan"* memicu pembukaan form Quality Report.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/order_tracking_screen_test.dart`  
Expected: FAIL

- [ ] **Step 3: Implement integrations**

1. Di `mobile/lib/screens/order_tracking_screen.dart`:
   - Tambahkan banner/kartu hijau di bawah Ambient Timer saat status `Selesai`:
     *"Pekerjaan Telah Selesai & Laporan Mutu Tersedia"* dengan tombol *"Lihat Laporan Mutu (Quality Report)"*.
   - Aksi navigasi ke `QualityReportScreen(order: order)`.
2. Di `mobile/lib/widgets/operational_simulation_sheet.dart`:
   - Ganti aksi transisi langsung saat status `Sedang Dikerjakan` $\rightarrow$ panggil `showModalBottomSheet` untuk menampilkan `QualityReportFormSheet`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/order_tracking_screen_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/order_tracking_screen.dart mobile/lib/widgets/operational_simulation_sheet.dart mobile/test/order_tracking_screen_test.dart
git commit -m "feat(mobile): integrate quality report viewer and submission triggers in tracking screen and simulation sheet"
```

---

### Task 10: Full End-to-End System Verification

**Files:**
- All modified files across `backend/` and `mobile/`.

- [ ] **Step 1: Run full Backend test suite**

Run: `cd backend && npm test`  
Expected: All 9 test suites PASS (100%).

- [ ] **Step 2: Run Flutter static analysis**

Run: `cd mobile && flutter analyze`  
Expected: 0 issues found.

- [ ] **Step 3: Run full Mobile test suite**

Run: `cd mobile && flutter test`  
Expected: All unit & widget tests PASS (100%).

- [ ] **Step 4: Git branch cleanup & merge to main**

```bash
git status
git log -n 5 --oneline
```
