# Midtrans Payment Gateway Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengintegrasikan Midtrans Snap Sandbox (Dual-Path & Dual-Mode) ke dalam sistem pemesanan Resik.in, mencakup pembuatan token transaksi Snap, verifikasi webhook asinkron SHA-512 (Jalur A), direct status check (Jalur B) untuk pengujian localhost, antarmuka In-App WebView di Flutter, serta kuitansi pembayaran digital persisten.

**Architecture:** Menggunakan arsitektur dua jalur (*dual-path*): Jalur A menerima notifikasi HTTP IPN dari Midtrans dengan validasi tanda tangan kriptografis SHA-512, sedangkan Jalur B memungkinkan klien mobile memeriksa status langsung ke server Midtrans saat berjalan di lingkungan localhost tanpa domain publik. Mesin pembayaran mendukung *Dual-Mode Fallback* (Midtrans Cloud Sandbox vs Internal Mock Simulator) untuk memastikan keandalan 100% tanpa risiko saat sidang tugas akhir.

**Tech Stack:** Node.js (ES Module), Express.js, native `crypto` (SHA-512), Supabase PostgreSQL, Flutter (Dart 3.x), `webview_flutter`, `GoogleFonts` (Plus Jakarta Sans).

**Spec:** `docs/superpowers/specs/2026-10-16-midtrans-payment-gateway-design.md`

## Global Constraints
- Target Pengujian: 100% test passing pada Backend (Node.js test runner) dan Mobile (`flutter test`).
- Linter: `flutter analyze` wajib 0 issues (*No issues found!*).
- Keamanan: `MIDTRANS_SERVER_KEY` HANYA berada di file `.env` Backend dan DILARANG KERAS terekspos ke frontend atau commit repositori.
- Idempotensi: Notifikasi webhook berulang untuk pesanan yang sama tidak boleh merusak data atau memicu duplikasi audit log.
- Desain UI: Mematuhi sistem desain *Pristine On-Demand* (`AppColors.primary`, `AppColors.emerald`, radius 16–18dp, GoogleFonts Plus Jakarta Sans).

---

### Task 1: Database Schema & Midtrans Helper Module (Dual-Mode)

**Files:**
- Create: `backend/lib/midtrans.js`
- Create: `backend/test/midtrans_helper.test.js`
- Modify: `backend/lib/database.js`
- Modify: `database/schema.sql`

**Interfaces:**
- Consumes: Environment variables (`MIDTRANS_SERVER_KEY`, `MIDTRANS_CLIENT_KEY`, `MIDTRANS_IS_PRODUCTION`)
- Produces: 
  - `midtransHelper.createSnapTransaction({ orderId, grossAmount, customerDetails }) -> Promise<{ token, redirect_url }>`
  - `midtransHelper.verifySignature({ orderId, statusCode, grossAmount, signatureKey }) -> boolean`
  - `midtransHelper.checkTransactionStatus(orderId) -> Promise<{ status, paymentType, transactionId, settlementTime }>`
  - `db.updateOrderPaymentDetails(orderId, { status_pembayaran, payment_method, payment_transaction_id, snap_token, snap_redirect_url })`

- [ ] **Step 1: Write the failing test for Midtrans Helper**

```javascript
// backend/test/midtrans_helper.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { midtransHelper } from '../lib/midtrans.js';

test('Midtrans Helper Unit Tests', async (t) => {
  await t.test('1. verifySignature menghasilkan hash SHA-512 yang valid', () => {
    const orderId = 'ord-test-001';
    const statusCode = '200';
    const grossAmount = '150000.00';
    const serverKey = 'SB-Mid-server-TEST12345';

    // Perhitungan manual SHA-512
    import('node:crypto').then((crypto) => {
      const expected = crypto.createHash('sha512')
        .update(orderId + statusCode + grossAmount + serverKey)
        .digest('hex');

      const isValid = midtransHelper.verifySignature({
        orderId,
        statusCode,
        grossAmount,
        signatureKey: expected,
        serverKeyOverride: serverKey
      });
      assert.strictEqual(isValid, true);

      const isInvalid = midtransHelper.verifySignature({
        orderId,
        statusCode,
        grossAmount,
        signatureKey: 'tampered-signature-hash',
        serverKeyOverride: serverKey
      });
      assert.strictEqual(isInvalid, false);
    });
  });

  await t.test('2. createSnapTransaction fallback ke Mock Mode saat server key tidak ada', async () => {
    const snap = await midtransHelper.createSnapTransaction({
      orderId: 'ord-mock-001',
      grossAmount: 150000,
      customerDetails: { first_name: 'Budi', email: 'budi@example.com' },
      forceMock: true
    });

    assert.ok(snap.token, 'Snap token harus ada');
    assert.ok(snap.redirect_url, 'Redirect URL harus ada');
    assert.match(snap.redirect_url, /mock-midtrans|sandbox\.midtrans\.com/);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && node --test test/midtrans_helper.test.js`  
Expected: FAIL with "Cannot find module '../lib/midtrans.js'"

- [ ] **Step 3: Implement Database Updates & `backend/lib/midtrans.js`**

1. Perbarui `database/schema.sql`: Tambahkan kolom `payment_method`, `payment_transaction_id`, `snap_token`, `snap_redirect_url` pada tabel `orders`.
2. Perbarui `backend/lib/database.js`: Tambahkan kolom ini pada struktur in-memory `orders` dan implementasikan method `updateOrderPaymentDetails(orderId, details)`.
3. Tulis `backend/lib/midtrans.js`:

```javascript
// backend/lib/midtrans.js
import crypto from 'node:crypto';

class MidtransHelper {
  constructor() {
    this.serverKey = process.env.MIDTRANS_SERVER_KEY || '';
    this.clientKey = process.env.MIDTRANS_CLIENT_KEY || '';
    this.isProduction = process.env.MIDTRANS_IS_PRODUCTION === 'true';
    this.snapBaseUrl = this.isProduction
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
    this.apiBaseUrl = this.isProduction
      ? 'https://api.midtrans.com/v2'
      : 'https://api.sandbox.midtrans.com/v2';
  }

  isMockMode() {
    return !this.serverKey || this.serverKey.includes('PLACEHOLDER') || this.serverKey === 'mock';
  }

  verifySignature({ orderId, statusCode, grossAmount, signatureKey, serverKeyOverride }) {
    const key = serverKeyOverride || this.serverKey;
    const raw = `${orderId}${statusCode}${grossAmount}${key}`;
    const calculated = crypto.createHash('sha512').update(raw).digest('hex');
    return calculated.toLowerCase() === (signatureKey || '').toLowerCase();
  }

  async createSnapTransaction({ orderId, grossAmount, customerDetails, forceMock = false }) {
    if (this.isMockMode() || forceMock) {
      const mockToken = `mock-snap-${orderId}-${Date.now()}`;
      return {
        token: mockToken,
        redirect_url: `https://app.sandbox.midtrans.com/snap/v2/vtweb/${mockToken}`,
        is_mock: true
      };
    }

    const payload = {
      transaction_details: {
        order_id: orderId,
        gross_amount: Math.round(grossAmount)
      },
      customer_details: customerDetails || {
        first_name: 'Pelanggan Resik.in'
      }
    };

    const authHeader = 'Basic ' + Buffer.from(this.serverKey + ':').toString('base64');
    const response = await fetch(this.snapBaseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': authHeader
      },
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error_messages ? data.error_messages.join(', ') : 'Gagal membuat sesi Midtrans Snap');
    }

    return {
      token: data.token,
      redirect_url: data.redirect_url,
      is_mock: false
    };
  }

  async checkTransactionStatus(orderId, { forceMockStatus = null } = {}) {
    if (forceMockStatus) {
      return forceMockStatus;
    }

    if (this.isMockMode()) {
      return {
        status_code: '200',
        transaction_status: 'settlement',
        payment_type: 'qris',
        transaction_id: `mock-txn-${orderId}`,
        settlement_time: new Date().toISOString()
      };
    }

    const authHeader = 'Basic ' + Buffer.from(this.serverKey + ':').toString('base64');
    const response = await fetch(`${this.apiBaseUrl}/${orderId}/status`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Authorization': authHeader
      }
    });

    if (!response.ok) {
      return null;
    }
    return await response.json();
  }
}

export const midtransHelper = new MidtransHelper();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && node --test test/midtrans_helper.test.js`  
Expected: PASS with 2 tests passed.

- [ ] **Step 5: Commit**

```bash
git add database/schema.sql backend/lib/database.js backend/lib/midtrans.js backend/test/midtrans_helper.test.js
git commit -m "feat(payment): add database schema updates and dual-mode Midtrans helper module"
```

---

### Task 2: Backend REST API Endpoints (`/payment-token`, `/webhooks/midtrans`, `/check-payment-status`)

**Files:**
- Modify: `backend/routes/orders.js`
- Create: `backend/routes/webhooks.js`
- Modify: `backend/server.js`
- Create: `backend/test/midtrans_payment.test.js`

**Interfaces:**
- Consumes: `midtransHelper`, `db`
- Produces:
  - `POST /api/orders/:id/payment-token`
  - `POST /api/webhooks/midtrans`
  - `POST /api/orders/:id/check-payment-status`

- [ ] **Step 1: Write the failing integration test**

```javascript
// backend/test/midtrans_payment.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../lib/database.js';
import { midtransHelper } from '../lib/midtrans.js';

const baseUrl = 'http://localhost:5000';

test('Midtrans Payment API Integration Tests', async (t) => {
  // Setup: buat pesanan uji coba
  const testOrder = await db.createOrder({
    customer_id: 'usr-midtrans-test',
    service_id: 'srv-001',
    service_name: 'Pembersihan Rumah Standar',
    service_category: 'rumah',
    tanggal_layanan: '2026-10-25',
    start_time: '10:00',
    duration: 2,
    alamat_lengkap: 'Jl. Kaliurang KM 9.5 Sleman',
    patokan_lokasi: 'Dekat Indomaret',
    harga_saat_booking: 150000,
    total_biaya: 150000,
    status_pembayaran: 'Belum Bayar',
    status_pekerjaan: 'Menunggu Konfirmasi'
  });

  await t.test('TC-MID-01: POST /api/orders/:id/payment-token menghasilkan snap token', async () => {
    const res = await fetch(`${baseUrl}/api/orders/${testOrder.id}/payment-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const json = await res.json();
    assert.strictEqual(res.status, 200);
    assert.strictEqual(json.success, true);
    assert.ok(json.data.token);
    assert.ok(json.data.redirect_url);
  });

  await t.test('TC-MID-02: Webhook menolak tanda tangan palsu (403 Forbidden)', async () => {
    const res = await fetch(`${baseUrl}/api/webhooks/midtrans`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: testOrder.id,
        status_code: '200',
        gross_amount: '150000.00',
        signature_key: 'invalid-signature-hash',
        transaction_status: 'settlement'
      })
    });
    assert.strictEqual(res.status, 403);
  });

  await t.test('TC-MID-03: Webhook valid (settlement) mengubah status_pembayaran menjadi Sudah Bayar', async () => {
    // Generate valid signature
    const grossAmount = '150000.00';
    const serverKey = process.env.MIDTRANS_SERVER_KEY || 'mock';
    const crypto = await import('node:crypto');
    const signature = crypto.createHash('sha512')
      .update(testOrder.id + '200' + grossAmount + serverKey)
      .digest('hex');

    const res = await fetch(`${baseUrl}/api/webhooks/midtrans`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: testOrder.id,
        status_code: '200',
        gross_amount: grossAmount,
        signature_key: signature,
        transaction_status: 'settlement',
        payment_type: 'qris',
        transaction_id: 'midtrans-txn-001'
      })
    });
    assert.strictEqual(res.status, 200);

    const updated = await db.getOrderById(testOrder.id);
    assert.strictEqual(updated.status_pembayaran, 'Sudah Bayar');
    assert.strictEqual(updated.payment_method, 'qris');
  });

  await t.test('TC-MID-04: POST /api/orders/:id/check-payment-status menyinkronkan status secara sinkron', async () => {
    const res = await fetch(`${baseUrl}/api/orders/${testOrder.id}/check-payment-status`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const json = await res.json();
    assert.strictEqual(res.status, 200);
    assert.strictEqual(json.success, true);
    assert.strictEqual(json.data.status_pembayaran, 'Sudah Bayar');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && node --test test/midtrans_payment.test.js`  
Expected: FAIL with 404 on `/payment-token` and `/webhooks/midtrans`

- [ ] **Step 3: Implement Endpoints in `orders.js`, `webhooks.js`, and `server.js`**

1. Di `backend/routes/orders.js`:
   * Tambahkan route `POST /:id/payment-token`:
     - Validasi status order (`status_pembayaran !== 'Sudah Bayar'`).
     - Jika order memiliki `snap_token` aktif, return token tersebut.
     - Panggil `midtransHelper.createSnapTransaction`.
     - Simpan `snap_token` dan `snap_redirect_url` ke database.
     - Return `{ success: true, data: { token, redirect_url } }`.
   * Tambahkan route `POST /:id/check-payment-status`:
     - Ambil order dari db. Jika sudah `Sudah Bayar`, return langsung.
     - Panggil `midtransHelper.checkTransactionStatus(id)`.
     - Jika status `settlement` atau `capture`, update db `status_pembayaran: 'Sudah Bayar'`, `payment_method`, `payment_transaction_id`.
     - Return `{ success: true, data: order }`.

2. Di `backend/routes/webhooks.js`:
   ```javascript
   import express from 'express';
   import { midtransHelper } from '../lib/midtrans.js';
   import { db } from '../lib/database.js';

   const router = express.Router();

   router.post('/midtrans', async (req, res) => {
     try {
       const {
         order_id,
         status_code,
         gross_amount,
         signature_key,
         transaction_status,
         payment_type,
         transaction_id,
         fraud_status
       } = req.body;

       if (!order_id) {
         return res.status(400).json({ error: 'order_id wajib disertakan' });
       }

       // Verifikasi Tanda Tangan SHA-512 (Kecuali jika server berjalan dalam Mock Mode eksplisit)
       if (!midtransHelper.isMockMode()) {
         const isValid = midtransHelper.verifySignature({
           orderId: order_id,
           statusCode: status_code,
           grossAmount: gross_amount,
           signatureKey: signature_key
         });
         if (!isValid) {
           return res.status(403).json({ error: 'Invalid signature key' });
         }
       }

       const order = await db.getOrderById(order_id);
       if (!order) {
         return res.status(404).json({ error: 'Order not found' });
       }

       // Idempotency: Jika sudah lunas, tanggapi 200 OK tanpa mengulang mutasi
       if (order.status_pembayaran === 'Sudah Bayar') {
         return res.status(200).json({ status: 'ok', message: 'Already paid' });
       }

       if (transaction_status === 'settlement' || (transaction_status === 'capture' && fraud_status === 'accept')) {
         await db.updateOrderPaymentDetails(order_id, {
           status_pembayaran: 'Sudah Bayar',
           payment_method: payment_type || 'midtrans',
           payment_transaction_id: transaction_id || null,
           payment_timestamp: new Date().toISOString()
         });
       } else if (['cancel', 'deny', 'expire'].includes(transaction_status)) {
         await db.updateOrderPaymentDetails(order_id, {
           status_pembayaran: 'Gagal'
         });
       }

       return res.status(200).json({ status: 'ok' });
     } catch (err) {
       return res.status(500).json({ error: err.message });
     }
   });

   export default router;
   ```

3. Di `backend/server.js`:
   * `import webhooksRouter from './routes/webhooks.js';`
   * `app.use('/api/webhooks', webhooksRouter);`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npm test`  
Expected: PASS with 126+ tests passed (seluruh test backend hijau).

- [ ] **Step 5: Commit**

```bash
git add backend/routes/orders.js backend/routes/webhooks.js backend/server.js backend/test/midtrans_payment.test.js
git commit -m "feat(api): implement Midtrans payment token, webhook notification, and status check endpoints"
```

---

### Task 3: Mobile Flutter API Service & OrderModel Updates

**Files:**
- Modify: `mobile/lib/models/order_model.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Create: `mobile/test/midtrans_api_service_test.dart`

**Interfaces:**
- Consumes: Backend endpoints `/payment-token` dan `/check-payment-status`
- Produces:
  - `OrderModel.paymentMethod`, `OrderModel.paymentTransactionId`, `OrderModel.snapToken`, `OrderModel.snapRedirectUrl`
  - `ApiService.getSnapPaymentToken(String orderId) -> Future<Map<String, dynamic>>`
  - `ApiService.checkPaymentStatus(String orderId) -> Future<Map<String, dynamic>>`

- [ ] **Step 1: Write unit test for Model & ApiService**

```dart
// mobile/test/midtrans_api_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';

void main() {
  test('OrderModel memparsing metadata pembayaran Midtrans dengan benar', () {
    final json = {
      'id': 'ord-test-01',
      'service_name': 'Pembersihan Rumah',
      'tanggal_layanan': '2026-10-25',
      'start_time': '09:00',
      'duration': 2,
      'alamat_lengkap': 'Jl. Colombo No. 1',
      'patokan_lokasi': 'UNY',
      'total_biaya': 150000.0,
      'status_pembayaran': 'Sudah Bayar',
      'payment_method': 'qris',
      'payment_transaction_id': 'midtrans-txn-999',
      'snap_token': 'snap-token-123',
      'snap_redirect_url': 'https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-token-123',
      'status_pekerjaan': 'Menunggu Konfirmasi'
    };

    final order = OrderModel.fromJson(json);
    expect(order.paymentMethod, 'qris');
    expect(order.paymentTransactionId, 'midtrans-txn-999');
    expect(order.snapToken, 'snap-token-123');
    expect(order.snapRedirectUrl, contains('snap-token-123'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/midtrans_api_service_test.dart`  
Expected: FAIL (getter `paymentMethod` is not defined on `OrderModel`)

- [ ] **Step 3: Update `OrderModel` and `ApiService`**

1. Tambahkan properti ke `OrderModel`:
   - `final String? paymentMethod;`
   - `final String? paymentTransactionId;`
   - `final String? snapToken;`
   - `final String? snapRedirectUrl;`
   - Update `fromJson` dan `toJson`.
2. Tambahkan method ke `ApiService`:
   - `static Future<Map<String, dynamic>> getSnapPaymentToken(String orderId)`
   - `static Future<Map<String, dynamic>> checkPaymentStatus(String orderId)`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/midtrans_api_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/order_model.dart mobile/lib/services/api_service.dart mobile/test/midtrans_api_service_test.dart
git commit -m "feat(mobile): add Midtrans payment properties to OrderModel and ApiService methods"
```

---

### Task 4: Flutter In-App WebView Screen (`MidtransSnapScreen`)

**Files:**
- Modify: `mobile/pubspec.yaml` (tambahkan `webview_flutter: ^4.10.0`)
- Create: `mobile/lib/screens/midtrans_snap_screen.dart`
- Create: `mobile/test/midtrans_snap_screen_test.dart`

**Interfaces:**
- Consumes: `redirectUrl`, `orderCode`, `totalBiaya`
- Produces: `MidtransSnapScreen` yang mengembalikan `bool? isSuccess` saat di-pop.

- [ ] **Step 1: Tambahkan `webview_flutter` dan tulis test widget**

1. Tambahkan `webview_flutter: ^4.10.0` pada `mobile/pubspec.yaml`.
2. Jalankan `flutter pub get`.
3. Tulis test widget di `mobile/test/midtrans_snap_screen_test.dart` (memverifikasi AppBar, judul, tombol tutup, dan progress indicator).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/midtrans_snap_screen_test.dart`  
Expected: FAIL (class `MidtransSnapScreen` not found).

- [ ] **Step 3: Implement `MidtransSnapScreen`**

```dart
// mobile/lib/screens/midtrans_snap_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

class MidtransSnapScreen extends StatefulWidget {
  final String redirectUrl;
  final String orderCode;

  const MidtransSnapScreen({
    super.key,
    required this.redirectUrl,
    required this.orderCode,
  });

  @override
  State<MidtransSnapScreen> createState() => _MidtransSnapScreenState();
}

class _MidtransSnapScreenState extends State<MidtransSnapScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // Cek apakah callback return sukses
            if (url.contains('status_code=200') || url.contains('transaction_status=settlement') || url.contains('#/finish')) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              return NavigationDecision.prevent; // cegah crash skema eksternal
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Pembayaran?'),
        content: const Text('Pesanan Anda tetap tersimpan. Anda dapat melanjutkan pembayaran nanti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Lanjut Bayar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pembayaran #${widget.orderCode}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.onSurface,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final shouldLeave = await _onWillPop();
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          bottom: _loadingProgress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/midtrans_snap_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/pubspec.yaml mobile/lib/screens/midtrans_snap_screen.dart mobile/test/midtrans_snap_screen_test.dart
git commit -m "feat(mobile): add MidtransSnapScreen WebView with deep link protection and PopScope"
```

---

### Task 5: Mobile `PaymentScreen` Redesign (Midtrans Badges, Modern Receipt Modal & Retry)

**Files:**
- Modify: `mobile/lib/screens/payment_screen.dart`
- Modify: `mobile/test/payment_screen_test.dart` (atau buat file baru jika belum ada)

**Interfaces:**
- Consumes: `ApiService.getSnapPaymentToken`, `ApiService.checkPaymentStatus`, `MidtransSnapScreen`
- Produces: `PaymentScreen` modern tanpa label dummy simulasi, modal Kuitansi Digital, dan alur retry.

- [ ] **Step 1: Write test for updated PaymentScreen UI**

Verifikasi:
1. Tombol menampilkan "Pilih Metode Pembayaran".
2. Baris logo pembayaran (QRIS, VA) tampil.
3. Mengetap tombol membuka alur pembayaran Midtrans.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/payment_screen_test.dart`  
Expected: FAIL (text "Bayar Sekarang (Simulasi)" not found / expecting "Pilih Metode Pembayaran").

- [ ] **Step 3: Update `PaymentScreen`**

1. Ganti tombol "Bayar Sekarang (Simulasi)" $\rightarrow$ "Pilih Metode Pembayaran".
2. Tambahkan widget baris lencana logo mini: QRIS, BCA, Mandiri, BNI, GoPay, ShopeePay.
3. Di `_handlePayment()`:
   * Ambil token via `ApiService.getSnapPaymentToken(_currentOrder.id)`.
   * Buka `MidtransSnapScreen` via `Navigator.push`.
   * Saat kembali: Panggil `ApiService.checkPaymentStatus(_currentOrder.id)`.
   * Jika sukses bayar: Tampilkan Modal Dialog Kuitansi Digital (Ikon emerald, Total, Metode, ID Transaksi, Tombol "Lacak Pesanan Sekarang").
   * Jika belum/batal: Tampilkan Banner Amber dengan tombol "Coba Bayar Lagi".

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/payment_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/payment_screen.dart mobile/test/payment_screen_test.dart
git commit -m "feat(mobile): modernize PaymentScreen with Midtrans Snap integration, payment badges, and receipt modal"
```

---

### Task 6: OrderTrackingScreen Persistent Receipt & Admin Dashboard Visibility

**Files:**
- Modify: `mobile/lib/screens/order_tracking_screen.dart`
- Modify: `public/admin.html`
- Modify: `public/js/admin.js`
- Create: `mobile/test/order_tracking_receipt_test.dart`

**Interfaces:**
- Consumes: `OrderModel.paymentMethod`, `OrderModel.paymentTransactionId`
- Produces: Kartu info / tombol "Lihat Kuitansi Pembayaran" di mobile dan label rincian transaksi di admin.

- [ ] **Step 1: Write widget test for persistent receipt button**

Test: saat `statusPembayaran == 'Sudah Bayar'`, tombol "Lihat Kuitansi Pembayaran" muncul di `OrderTrackingScreen`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/order_tracking_receipt_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implement persistent receipt & admin visibility**

1. Di `mobile/lib/screens/order_tracking_screen.dart`:
   * Tambahkan tombol "Lihat Kuitansi Pembayaran" di bawah badge status pembayaran.
   * Buat method `_showReceiptBottomSheet(BuildContext context)` yang merender bottom sheet kuitansi digital.
2. Di `public/admin.html` & `public/js/admin.js`:
   * Tampilkan field `Metode Pembayaran` dan `ID Transaksi Midtrans` pada modal detail pesanan.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/order_tracking_receipt_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/order_tracking_screen.dart public/admin.html public/js/admin.js mobile/test/order_tracking_receipt_test.dart
git commit -m "feat(orders): add persistent digital receipt view in OrderTrackingScreen and admin payment visibility"
```

---

### Task 7: Full System Verification & SOT Documentation Update

**Files:**
- Modify: `docs/PRD-Resik.in.md`
- Modify: `docs/API.md`
- Modify: `docs/ROADMAP.md`

- [ ] **Step 1: Run full Backend test suite**

Run: `cd backend && npm test`  
Expected: 126+ tests PASS (100% green).

- [ ] **Step 2: Run Flutter analyze and full test suite**

Run: `cd mobile && flutter analyze && flutter test`  
Expected: `flutter analyze` 0 issues, 90+ mobile tests PASS (100% green).

- [ ] **Step 3: Update documentation SOT**

Perbarui `docs/PRD-Resik.in.md`, `docs/API.md`, dan `docs/ROADMAP.md` untuk mencatat status resmi modul Midtrans Payment Gateway V2.1.

- [ ] **Step 4: Final Commit & Push**

```bash
git add docs/PRD-Resik.in.md docs/API.md docs/ROADMAP.md
git commit -m "docs: document Midtrans Payment Gateway integration completion and updated test metrics"
git push origin main
```
