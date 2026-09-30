# Phase 2: Customer Rating & Review (FR-11) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun modul rating dan ulasan pelanggan (FR-11) end-to-end yang memungkinkan pelanggan memberikan bintang 1–5 dan catatan setelah pesanan selesai, secara otomatis mengagregasi rating reputasi petugas, dan menampilkannya pada profil petugas.

**Architecture:** Menerapkan arsitektur REST API modular (`/api/reviews`) pada backend Express.js dengan agregasi reputasi sinkron ganda (database trigger Supabase & in-memory fallback), dipadukan dengan modal interaktif `ReviewBottomSheet` pada Flutter serta integrasi tampilan pada `OrderTrackingScreen`, `QualityReportScreen`, dan `CleanerDetailScreen`.

**Tech Stack:** Node.js (ES Module), Express.js, Supabase PostgreSQL, Flutter (Dart), `http`, `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-09-30-phase-2-customer-review-design.md](file:///C:/Users/62859/Documents/Skripsi/Resik.in/docs/superpowers/specs/2026-09-30-phase-2-customer-review-design.md)

## Global Constraints

- Backend menggunakan arsitektur ES Module (`"type": "module"`).
- Seluruh endpoint API merespons dengan format amplop JSON standar: `{ "success": boolean, "message": string, "data": object|array }`.
- Status pesanan wajib `selesai` sebelum ulasan dapat dibuat.
- Hak akses: Hanya pelanggan pemilik pesanan (`order.customer_id`) yang berhak mengirim ulasan (`403 Forbidden` untuk selain pemilik).
- Anti-duplikasi (*One review per order*): Upaya mengulas kembali pesanan yang sudah memiliki ulasan wajib ditolak dengan HTTP `409 Conflict`.
- Nilai rating integer $1 \le \text{rating} \le 5$, catatan ulasan opsional $\le 300$ karakter.
- Fixture test otomatis menggunakan prefix ID `rev-test-*` dan terisolasi dari `.in_memory_state.json`.
- Tidak boleh memicu regresi pada 57 backend tests yang sudah ada dan 35 mobile tests.

---

### Task 1: In-Memory Store & Database Aggregation Logic for Reviews

**Files:**
- Modify: `backend/lib/supabase.js`
- Test: `backend/test/reviews_store.test.js`

**Interfaces:**
- Consumes: `orders`, `cleaners`, `profiles` in-memory collections and Supabase client in `backend/lib/supabase.js`.
- Produces: `reviews` collection in `store`, `updateCleanerRating(cleanerId)` helper, fixture exclusion for `rev-test-*` in `persistState()`.

- [ ] **Step 1: Write the failing test for review store and aggregation**

Create `backend/test/reviews_store.test.js`:
```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import { supabase, store } from '../lib/supabase.js';

test('Reviews Store & Rating Aggregation In-Memory Logic', async (t) => {
  await t.test('1. Menambahkan ulasan baru dan menghitung ulang rating_rata_rata cleaner secara otomatis', async () => {
    // Setup test cleaner
    const testCleanerId = 'cln-test-agg-01';
    store.cleaners.set(testCleanerId, {
      id: testCleanerId,
      nama: 'Petugas Test Agg',
      rating_rata_rata: 4.5,
      total_ulasan: 0,
      total_pekerjaan: 5
    });

    // Masukkan ulasan pertama: rating 5
    store.reviews.set('rev-test-1', {
      id: 'rev-test-1',
      order_id: 'ord-test-agg-1',
      cleaner_id: testCleanerId,
      customer_id: 'usr-cust-001',
      rating: 5,
      catatan_ulasan: 'Sangat bagus',
      created_at: new Date().toISOString()
    });

    // Masukkan ulasan kedua: rating 4
    store.reviews.set('rev-test-2', {
      id: 'rev-test-2',
      order_id: 'ord-test-agg-2',
      cleaner_id: testCleanerId,
      customer_id: 'usr-cust-002',
      rating: 4,
      catatan_ulasan: 'Cukup bersih',
      created_at: new Date().toISOString()
    });

    // Hitung agregasi ulasan untuk cleaner
    const cleanerReviews = Array.from(store.reviews.values()).filter(r => r.cleaner_id === testCleanerId);
    const avgRating = cleanerReviews.reduce((sum, r) => sum + r.rating, 0) / cleanerReviews.length;
    const roundedAvg = Math.round(avgRating * 10) / 10;

    const cleaner = store.cleaners.get(testCleanerId);
    cleaner.rating_rata_rata = roundedAvg;
    cleaner.total_ulasan = cleanerReviews.length;

    assert.equal(cleaner.rating_rata_rata, 4.5);
    assert.equal(cleaner.total_ulasan, 2);

    // Tambah ulasan ketiga: rating 2 (sehingga (5 + 4 + 2) / 3 = 11 / 3 = 3.666 -> 3.7)
    store.reviews.set('rev-test-3', {
      id: 'rev-test-3',
      order_id: 'ord-test-agg-3',
      cleaner_id: testCleanerId,
      customer_id: 'usr-cust-003',
      rating: 2,
      catatan_ulasan: 'Kurang bersih',
      created_at: new Date().toISOString()
    });

    const updatedReviews = Array.from(store.reviews.values()).filter(r => r.cleaner_id === testCleanerId);
    const newAvg = updatedReviews.reduce((sum, r) => sum + r.rating, 0) / updatedReviews.length;
    cleaner.rating_rata_rata = Math.round(newAvg * 10) / 10;
    cleaner.total_ulasan = updatedReviews.length;

    assert.equal(cleaner.rating_rata_rata, 3.7);
    assert.equal(cleaner.total_ulasan, 3);
  });
});
```

- [ ] **Step 2: Run test to verify store.reviews exists or fails**

Run: `node --test backend/test/reviews_store.test.js`
Expected: Fails or passes depending on `store.reviews` presence.

- [ ] **Step 3: Update `backend/lib/supabase.js` to initialize `reviews` collection and persistence filtering**

In `backend/lib/supabase.js`:
Add `reviews: new Map()` to `store`.
In `loadPersistedState()`: load `parsed.reviews`.
In `persistState()`: filter out `rev-test-*` and `rev-qr-*` fixtures so they do not pollute `.in_memory_state.json`.

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/reviews_store.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/lib/supabase.js backend/test/reviews_store.test.js
git commit -m "feat(backend): add reviews store collection and aggregation logic with test isolation"
```

---

### Task 2: Backend REST API Endpoints (`/api/reviews`) & 5-Step Validation Pipeline

**Files:**
- Create: `backend/routes/reviews.js`
- Modify: `backend/server.js`
- Test: `backend/test/reviews.test.js`

**Interfaces:**
- Consumes: Express router, `store` & `supabase` from `backend/lib/supabase.js`.
- Produces: `POST /api/reviews`, `GET /api/reviews/order/:order_id`, `GET /api/reviews/cleaner/:cleaner_id`.

- [ ] **Step 1: Write the failing tests for reviews REST API**

Create `backend/test/reviews.test.js`:
```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'http';
import app from '../server.js';
import { store } from '../lib/supabase.js';

let server;
let baseUrl;

test.before(async () => {
  await new Promise((resolve) => {
    server = http.createServer(app);
    server.listen(0, () => {
      const port = server.address().port;
      baseUrl = `http://127.0.0.1:${port}`;
      resolve();
    });
  });
});

test.after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('POST /api/reviews — 5-Step Validation Pipeline', async (t) => {
  const custId = 'usr-cust-001';
  const otherCustId = 'usr-stranger-999';
  const cleanerId = 'cln-test-rev-01';
  const orderCompletedId = 'ord-test-rev-completed';
  const orderInProgressId = 'ord-test-rev-progress';

  // Seed fixtures
  store.cleaners.set(cleanerId, {
    id: cleanerId,
    nama: 'Budi Santoso',
    rating_rata_rata: 4.5,
    total_ulasan: 0,
    total_pekerjaan: 10
  });

  store.orders.set(orderCompletedId, {
    id: orderCompletedId,
    customer_id: custId,
    cleaner_id: cleanerId,
    service_id: 'srv-001',
    status_pekerjaan: 'selesai'
  });

  store.orders.set(orderInProgressId, {
    id: orderInProgressId,
    customer_id: custId,
    cleaner_id: cleanerId,
    service_id: 'srv-001',
    status_pekerjaan: 'sedang_dikerjakan'
  });

  await t.test('1. Validasi rating di luar rentang (0 atau 6) ditolak dengan 400', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: custId,
        rating: 6,
        catatan_ulasan: 'Terlalu sempurna'
      })
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'INVALID_RATING');
  });

  await t.test('2. Validasi status pesanan belum selesai ditolak dengan 400', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderInProgressId,
        user_id: custId,
        rating: 5
      })
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'ORDER_NOT_COMPLETED');
  });

  await t.test('3. Validasi hak akses bukan pemilik order ditolak dengan 403', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: otherCustId,
        rating: 5
      })
    });
    assert.equal(res.status, 403);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'FORBIDDEN_NOT_ORDER_OWNER');
  });

  await t.test('4. Pengiriman ulasan valid berhasil (201 Created) dan memperbarui rating cleaner', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: custId,
        rating: 5,
        catatan_ulasan: 'Kamar sangat wangi dan bersih!'
      })
    });
    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.rating, 5);
    assert.equal(body.data.cleaner_summary.rating_rata_rata, 5.0);
    assert.equal(body.data.cleaner_summary.total_ulasan, 1);
  });

  await t.test('5. Pengiriman ulasan duplikat pada order yang sama ditolak dengan 409 Conflict', async () => {
    const res = await fetch(`${baseUrl}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: orderCompletedId,
        user_id: custId,
        rating: 4,
        catatan_ulasan: 'Coba lagi'
      })
    });
    assert.equal(res.status, 409);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'REVIEW_ALREADY_EXISTS');
  });

  await t.test('6. GET /api/reviews/order/:order_id mengembalikan ulasan yang tersimpan', async () => {
    const res = await fetch(`${baseUrl}/api/reviews/order/${orderCompletedId}`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.rating, 5);
  });

  await t.test('7. GET /api/reviews/cleaner/:cleaner_id mengembalikan daftar ulasan dengan masking nama pelanggan', async () => {
    const res = await fetch(`${baseUrl}/api/reviews/cleaner/${cleanerId}`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.data.total_ulasan, 1);
    assert.ok(body.data.reviews.length >= 1);
    assert.ok(body.data.reviews[0].customer_name);
  });
});
```

- [ ] **Step 2: Run test to verify it fails (route not mounted)**

Run: `node --test backend/test/reviews.test.js`
Expected: FAIL with 404 (endpoint not found)

- [ ] **Step 3: Implement `backend/routes/reviews.js`**

Implement router in `backend/routes/reviews.js`:
- `POST /`:
  - Validasi parameter `order_id`, `rating`.
  - Lookup order dari database/in-memory store. Jika tak ditemukan $\rightarrow$ 404.
  - Cek `user_id` / auth terhadap `order.customer_id`. Jika mismatch $\rightarrow$ 403.
  - Cek `order.status_pekerjaan === 'selesai'`. Jika belum $\rightarrow$ 400 `ORDER_NOT_COMPLETED`.
  - Cek `rating >= 1 && rating <= 5`. Jika invalid $\rightarrow$ 400 `INVALID_RATING`.
  - Cek apakah order sudah di-review di `reviews` collection. Jika sudah $\rightarrow$ 409 `REVIEW_ALREADY_EXISTS`.
  - Simpan review baru.
  - Hitung ulang agregasi ulasan untuk `cleaner_id` terkait.
  - Return 201 dengan data review + `cleaner_summary`.
- `GET /order/:order_id`:
  - Lookup review berdasarkan `order_id`. Jika ada $\rightarrow$ 200, jika tidak $\rightarrow$ 404.
- `GET /cleaner/:cleaner_id`:
  - Filter reviews untuk `cleaner_id`.
  - Format customer name masking (contoh: "Ahmad F." atau "Pelanggan Resik.in").
  - Return 200 dengan `cleaner_id`, `rating_rata_rata`, `total_ulasan`, `reviews`.

Mount in `backend/server.js`:
```javascript
import reviewsRouter from './routes/reviews.js';
...
app.use('/api/reviews', reviewsRouter);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/reviews.test.js`
Expected: PASS (all 7 sub-tests pass)

- [ ] **Step 5: Run all backend tests to ensure no regressions**

Run: `cd backend && npm test`
Expected: PASS (all 12 suites, 60+ tests passing)

- [ ] **Step 6: Commit**

```bash
git add backend/routes/reviews.js backend/server.js backend/test/reviews.test.js
git commit -m "feat(backend): implement customer review endpoints with 5-stage validation and rating aggregation"
```

---

### Task 3: Mobile Model & HTTP Service (`ReviewModel` & `ReviewService`)

**Files:**
- Create: `mobile/lib/models/review_model.dart`
- Create: `mobile/lib/services/review_service.dart`
- Test: `mobile/test/review_model_test.dart`
- Test: `mobile/test/review_service_test.dart`

**Interfaces:**
- Consumes: `http` package, `baseUrl` config from `mobile/lib/services/`.
- Produces: `ReviewModel`, `ReviewService` with `submitReview()`, `getReviewByOrderId()`, `getCleanerReviews()`.

- [ ] **Step 1: Write model test**

Create `mobile/test/review_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/review_model.dart';

void main() {
  group('ReviewModel Tests', () {
    test('Deserialisasi JSON valid ke ReviewModel', () {
      final json = {
        'id': 'rev-001',
        'order_id': 'ord-001',
        'customer_id': 'usr-001',
        'customer_name': 'Ahmad F.',
        'cleaner_id': 'cln-001',
        'rating': 5,
        'catatan_ulasan': 'Pekerjaan rapi sekali',
        'created_at': '2026-09-30T10:00:00Z',
      };

      final model = ReviewModel.fromJson(json);

      expect(model.id, 'rev-001');
      expect(model.orderId, 'ord-001');
      expect(model.rating, 5);
      expect(model.catatanUlasan, 'Pekerjaan rapi sekali');
      expect(model.customerName, 'Ahmad F.');
    });

    test('Serialisasi ReviewModel ke JSON', () {
      final model = ReviewModel(
        id: 'rev-002',
        orderId: 'ord-002',
        customerId: 'usr-002',
        cleanerId: 'cln-002',
        rating: 4,
        catatanUlasan: 'Cukup bagus',
        createdAt: DateTime.parse('2026-09-30T10:00:00Z'),
      );

      final json = model.toJson();
      expect(json['order_id'], 'ord-002');
      expect(json['rating'], 4);
      expect(json['catatan_ulasan'], 'Cukup bagus');
    });
  });
}
```

- [ ] **Step 2: Implement `ReviewModel`**

Create `mobile/lib/models/review_model.dart`:
Properties: `id`, `orderId`, `customerId`, `customerName`, `cleanerId`, `rating`, `catatanUlasan`, `createdAt`.
Include `fromJson` and `toJson`.

- [ ] **Step 3: Write service test & implement `ReviewService`**

Create `mobile/test/review_service_test.dart` and `mobile/lib/services/review_service.dart`.
Methods:
- `Future<ReviewModel?> submitReview({required String orderId, required int rating, String? catatanUlasan, String? userId})`
- `Future<ReviewModel?> getReviewByOrderId(String orderId)`
- `Future<List<ReviewModel>> getCleanerReviews(String cleanerId)`

- [ ] **Step 4: Run tests**

Run: `cd mobile && flutter test test/review_model_test.dart test/review_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/review_model.dart mobile/lib/services/review_service.dart mobile/test/review_model_test.dart mobile/test/review_service_test.dart
git commit -m "feat(mobile): add ReviewModel and ReviewService with unit tests"
```

---

### Task 4: Mobile Interactive UI Widget (`ReviewBottomSheet`)

**Files:**
- Create: `mobile/lib/widgets/review_bottom_sheet.dart`
- Test: `mobile/test/review_bottom_sheet_test.dart`

**Interfaces:**
- Consumes: `ReviewService`, `AppColors` from `mobile/lib/theme/app_theme.dart`.
- Produces: `ReviewBottomSheet` widget callable via `showModalBottomSheet(context: context, builder: (ctx) => ReviewBottomSheet(...))`.

- [ ] **Step 1: Write widget test for `ReviewBottomSheet`**

Create `mobile/test/review_bottom_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/review_bottom_sheet.dart';

void main() {
  testWidgets('ReviewBottomSheet menampilkan bintang interaktif dan tombol teraktivasi saat rating dipilih', (tester) async {
    int? selectedRating;
    String? submittedNotes;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewBottomSheet(
            orderId: 'ord-123',
            cleanerName: 'Budi Santoso',
            serviceName: 'Pembersihan Kos',
            onSubmit: (rating, notes) async {
              selectedRating = rating;
              submittedNotes = notes;
              return true;
            },
          ),
        ),
      ),
    );

    // Verifikasi header
    expect(find.text('Beri Ulasan Petugas'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);

    // Tombol kirim ulasan awalnya disabled
    final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Kirim Ulasan');
    expect(submitButtonFinder, findsOneWidget);
    ElevatedButton btn = tester.widget(submitButtonFinder);
    expect(btn.onPressed, isNull);

    // Tekan bintang ke-5
    final starIcons = find.byIcon(Icons.star_rounded);
    expect(starIcons, findsNWidgets(5));
    await tester.tap(starIcons.at(4));
    await tester.pumpAndSettle();

    // Verifikasi label emosional muncul
    expect(find.text('Sangat Puas & Bersih'), findsOneWidget);

    // Tombol kirim sekarang aktif
    btn = tester.widget(submitButtonFinder);
    expect(btn.onPressed, isNotNull);

    // Ketik catatan
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Pelayanan luar biasa');
    await tester.pumpAndSettle();

    // Tekan submit
    await tester.tap(submitButtonFinder);
    await tester.pumpAndSettle();

    expect(selectedRating, 5);
    expect(submittedNotes, 'Pelayanan luar biasa');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/review_bottom_sheet_test.dart`
Expected: FAIL (file not found)

- [ ] **Step 3: Implement `mobile/lib/widgets/review_bottom_sheet.dart`**

Implement:
- Star rating selector row (1..5 stars).
- Dynamic emotional text badge:
  - 1: "Sangat Kurang"
  - 2: "Kurang Memuaskan"
  - 3: "Cukup"
  - 4: "Memuaskan"
  - 5: "Sangat Puas & Bersih"
- TextField (max 300 chars) for `catatan_ulasan`.
- Double-click prevention (`_isSubmitting`).
- Submit callback handling with success/error feedback.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/review_bottom_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/review_bottom_sheet.dart mobile/test/review_bottom_sheet_test.dart
git commit -m "feat(mobile): implement interactive ReviewBottomSheet with star ratings and emotional labels"
```

---

### Task 5: Screen Integration on Order Tracking & Quality Report

**Files:**
- Modify: `mobile/lib/screens/order_tracking_screen.dart`
- Modify: `mobile/lib/screens/quality_report_screen.dart`
- Test: `mobile/test/order_tracking_review_test.dart`

**Interfaces:**
- Consumes: `ReviewBottomSheet`, `ReviewService`.
- Produces: Persistent rating status check when order is `selesai`, CTA button to trigger review sheet, read-only review card when reviewed.

- [ ] **Step 1: Write integration widget test**

Create `mobile/test/order_tracking_review_test.dart`:
Verify that when `order.statusPekerjaan == 'selesai'`:
- Displays button "Beri Rating & Ulasan" when order has no review.
- Displays review card with star rating when review is present.

- [ ] **Step 2: Update `mobile/lib/screens/order_tracking_screen.dart`**

- Add state `ReviewModel? _existingReview;` and `bool _isLoadingReview = false;`.
- On order fetch / status change to `selesai`: call `_reviewService.getReviewByOrderId(orderId)`.
- If `_existingReview == null`: render button `[⭐ Beri Rating & Ulasan Petugas]`. On tap: show `ReviewBottomSheet`. When submitted successfully: update `_existingReview` state and call `setState()`.
- If `_existingReview != null`: render card `Ulasan Anda: ⭐ ${_existingReview!.rating}/5 — ${_existingReview!.catatanUlasan}` with locked badge.

- [ ] **Step 3: Update `mobile/lib/screens/quality_report_screen.dart`**

- In footer below Before/After comparison and checklist:
  - Add same review CTA button or card summary so user inspecting the report can immediately review.

- [ ] **Step 4: Run tests**

Run: `cd mobile && flutter test test/order_tracking_review_test.dart test/order_tracking_screen_test.dart test/quality_report_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/order_tracking_screen.dart mobile/lib/screens/quality_report_screen.dart mobile/test/order_tracking_review_test.dart
git commit -m "feat(mobile): integrate customer review CTA and summary card on order tracking and quality report screens"
```

---

### Task 6: Screen Integration on Cleaner Profile (`CleanerDetailScreen`)

**Files:**
- Modify: `mobile/lib/screens/cleaner_detail_screen.dart`
- Test: `mobile/test/cleaner_detail_review_test.dart`

**Interfaces:**
- Consumes: `ReviewService`, `cleaner.totalUlasan`, `cleaner.ratingRataRata`.
- Produces: Dynamic customer review section on cleaner detail screen, hiding provisional badge when real reviews exist.

- [ ] **Step 1: Write widget test for cleaner detail review list**

Create `mobile/test/cleaner_detail_review_test.dart`:
- Verify that when `cleaner.totalUlasan > 0`, the banner "Petugas Baru (Rating Awal 4.5)" is hidden.
- Verify that customer reviews section is rendered with reviewer name, rating stars, and comment text.

- [ ] **Step 2: Update `mobile/lib/screens/cleaner_detail_screen.dart`**

- In `CleanerDetailScreen`: load reviews via `ReviewService().getCleanerReviews(cleaner.id)`.
- If `cleaner.totalUlasan > 0` or reviews list is not empty:
  - Hide provisional rating banner.
  - Display "Ulasan Pelanggan (${cleaner.totalUlasan} Ulasan)".
  - Render list of review cards (customer initial/masked name, star rating row, date, and review note).

- [ ] **Step 3: Run test to verify it passes**

Run: `cd mobile && flutter test test/cleaner_detail_review_test.dart test/cleaner_detail_screen_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/screens/cleaner_detail_screen.dart mobile/test/cleaner_detail_review_test.dart
git commit -m "feat(mobile): display verified customer reviews list and dynamic reputation on cleaner detail screen"
```

---

### Task 7: Comprehensive Verification & Full Regression Suite

**Files:**
- Entire repository

**Interfaces:**
- Full system verification

- [ ] **Step 1: Run complete backend test suite**

Run: `cd backend && npm test`
Expected: 100% pass across all test suites (target: 65+ tests passing, 0 fails).

- [ ] **Step 2: Run mobile analyzer**

Run: `cd mobile && flutter analyze`
Expected: No issues found!

- [ ] **Step 3: Run complete mobile test suite**

Run: `cd mobile && flutter test`
Expected: 100% pass across all mobile tests (target: 40+ tests passing, 0 fails).

- [ ] **Step 4: Final verification commit & tag ready**

```bash
git add -A
git commit -m "chore(release): complete phase 2 customer rating and review verification"
```
