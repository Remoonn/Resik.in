# Multi-Role Dedicated Dashboards (Admin, Cleaner, Customer) & Operational Simulation Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menggantikan lembar bantuan sementara `OperationalSimulationSheet` dengan arsitektur dasbor terdedikasi berbasis peran (`AdminDashboardScreen`, `CleanerDashboardScreen`, `HomeScreen`) dan pembaruan pelacakan pelanggan mandiri melalui *adaptive short-polling*.

**Architecture:** Declarative Role-Based Routing di `AuthGate` (`main.dart`) mengarahkan sesi pengguna berdasarkan atribut `user.role`. Layar Petugas (`CleanerDashboardScreen`) mengelola tugas aktif dengan tombol transisi status sekuensial dan pengiriman laporan mutu digital. Layar Admin (`AdminDashboardScreen`) bertindak sebagai menara kendali operasional dengan filter status, *pipeline counters*, serta penugasan petugas bebas bentrok (*Smart Matching*). Layar Pelanggan (`OrderTrackingScreen`) dibersihkan dari tombol simulasi dan diperkuat dengan *Pull-to-Refresh* serta *Lifecycle-Aware Short-Polling* (10 detik).

**Tech Stack:** Flutter 3.x (Dart), Provider/ValueNotifier state reaktif, HTTP REST API (Express.js), Supabase PostgreSQL Cloud, `url_launcher` (Google Maps intent).

**Spec:** [`docs/superpowers/specs/2026-10-04-multi-role-dashboard-design.md`](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/superpowers/specs/2026-10-04-multi-role-dashboard-design.md)

## Global Constraints
- Minimal Diff Principle: Jangan merombak kode atau test yang sudah stabil tanpa kebutuhan spesifik.
- Aturan Bisnis Mutlak:
  - *BR-FIN-001*: Konfirmasi pesanan (`Menunggu Konfirmasi` $\rightarrow$ `Dikonfirmasi`) hanya diizinkan jika `status_pembayaran == 'Sudah Bayar'`.
  - *BR-STS-001*: Transisi status lapangan (`Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`) wajib sekuensial tanpa melompati tahapan.
  - *BR-STS-002*: Transisi ke status `Selesai` adalah hak eksklusif Cleaner dan **wajib** melalui pengiriman Quality Report (`POST /api/quality-reports`).
  - *BR-ASN-001*: Penugasan petugas memperhitungkan bentrok jadwal dengan buffer operasional 30 menit.
  - *BR-ASN-003*: Reassign dan pembatalan pesanan wajib menyertakan alasan minimal 5 karakter.
- Keamanan: `SUPABASE_SERVICE_ROLE_KEY` dilarang keras dibocorkan ke kode Flutter (`mobile/`).

---

### Task 1: Role Context & Service Enhancement (`ApiService` & `AuthService`)

**Files:**
- Modify: `mobile/lib/services/api_service.dart:164-215`
- Modify: `mobile/lib/services/auth_service.dart:180-186`
- Test: `mobile/test/api_service_role_test.dart`

**Interfaces:**
- Consumes: `UserModel` (`cleanerId`, `role`), `ApiConstants.baseUrl`.
- Produces: `ApiService.fetchOrders({String? status, String? customerId, String? cleanerId, String? role})`, `AuthService.authHeaders`.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/api_service_role_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in/models/user_model.dart';
import 'package:resik_in/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService & Role Header Tests', () {
    test('AuthService.authHeaders returns correct headers for customer, cleaner, and admin', () {
      final auth = AuthService();

      // Test Cleaner Headers
      final cleanerUser = const UserModel(
        id: 'usr-cleaner-001',
        nama: 'Cecep',
        email: 'cecep@resik.in',
        role: 'cleaner',
        cleanerId: 'cln-001',
      );
      AuthService.currentUserNotifier.value = cleanerUser;
      expect(auth.authHeaders['x-user-id'], 'usr-cleaner-001');
      expect(auth.authHeaders['x-user-role'], 'cleaner');
      expect(auth.authHeaders['x-cleaner-id'], 'cln-001');

      // Test Admin Headers
      final adminUser = const UserModel(
        id: 'usr-admin-001',
        nama: 'Admin Resik',
        email: 'admin@resik.in',
        role: 'admin',
      );
      AuthService.currentUserNotifier.value = adminUser;
      expect(auth.authHeaders['x-user-id'], 'usr-admin-001');
      expect(auth.authHeaders['x-user-role'], 'admin');
      expect(auth.authHeaders.containsKey('x-cleaner-id'), false);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api_service_role_test.dart`
Expected: FAIL (getter `authHeaders` not defined on `AuthService`).

- [ ] **Step 3: Implement minimal code in `auth_service.dart` and `api_service.dart`**

In `mobile/lib/services/auth_service.dart`, add getter `authHeaders`:
```dart
  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (currentUser != null && currentUser!.id.isNotEmpty) 'x-user-id': currentUser!.id,
    if (currentUser != null && currentUser!.role.isNotEmpty) 'x-user-role': currentUser!.role,
    if (currentUser?.cleanerId != null && currentUser!.cleanerId!.isNotEmpty) 'x-cleaner-id': currentUser!.cleanerId!,
  };
```

In `mobile/lib/services/api_service.dart`, update `fetchOrders` to support `cleanerId`:
```dart
  static Future<List<OrderModel>> fetchOrders({
    String? status,
    String? customerId,
    String? cleanerId,
    String? role,
  }) async {
    try {
      final user = AuthService().currentUser;
      final effectiveUserId = customerId ?? (user?.isCleaner == true ? null : user?.id);
      final effectiveCleanerId = cleanerId ?? user?.cleanerId;
      final effectiveRole = role ?? user?.role ?? 'customer';

      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
        queryParams['customer_id'] = effectiveUserId;
      }
      if (effectiveCleanerId != null && effectiveCleanerId.isNotEmpty) {
        queryParams['cleaner_id'] = effectiveCleanerId;
      }
      if (effectiveRole.isNotEmpty) {
        queryParams['role'] = effectiveRole;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/orders').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (user != null && user.id.isNotEmpty) 'x-user-id': user.id,
        if (effectiveRole.isNotEmpty) 'x-user-role': effectiveRole,
        if (effectiveCleanerId != null && effectiveCleanerId.isNotEmpty) 'x-cleaner-id': effectiveCleanerId,
      };

      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final List list = body['data'];
          final allOrders = list.map((item) => OrderModel.fromJson(item)).toList();

          // Client-side safety filter: isolasi pesanan pelanggan vs petugas
          if (effectiveRole == 'cleaner' && effectiveCleanerId != null && effectiveCleanerId.isNotEmpty) {
            return allOrders.where((o) => o.cleanerId == effectiveCleanerId).toList();
          } else if (effectiveRole != 'admin' && effectiveUserId != null && effectiveUserId.isNotEmpty) {
            return allOrders.where((o) => o.customerId == effectiveUserId).toList();
          }
          return allOrders;
        }
      }
      return <OrderModel>[];
    } catch (e) {
      return <OrderModel>[];
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/api_service_role_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/auth_service.dart mobile/lib/services/api_service.dart mobile/test/api_service_role_test.dart
git commit -m "feat(mobile): add authHeaders getter and cleaner support in fetchOrders"
```

---

### Task 2: Cleaner Dedicated Dashboard (`CleanerDashboardScreen`)

**Files:**
- Create: `mobile/lib/screens/cleaner_dashboard_screen.dart`
- Test: `mobile/test/cleaner_dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `ApiService.fetchOrders`, `ApiService.updateOrderStatus`, `AuthService.currentUser`, `OrderModel`, `QualityReportScreen`.
- Produces: `CleanerDashboardScreen` widget with Tab 1 (Tugas Berjalan), Tab 2 (Riwayat Tugas), profile header, sequential action buttons, and pull-to-refresh.

- [ ] **Step 1: Write the failing widget test**

Create `mobile/test/cleaner_dashboard_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in/models/order_model.dart';
import 'package:resik_in/models/user_model.dart';
import 'package:resik_in/screens/cleaner_dashboard_screen.dart';
import 'package:resik_in/services/auth_service.dart';

void main() {
  testWidgets('CleanerDashboardScreen renders header, tabs, and empty state correctly', (WidgetTester tester) async {
    const cleaner = UserModel(
      id: 'usr-cleaner-001',
      nama: 'Cecep Cleaner',
      email: 'cecep@resik.in',
      role: 'cleaner',
      cleanerId: 'cln-001',
    );
    AuthService.currentUserNotifier.value = cleaner;

    await tester.pumpWidget(
      MaterialApp(
        home: CleanerDashboardScreen(
          ordersLoader: () async => <OrderModel>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header elements
    expect(find.text('Cecep Cleaner'), findsOneWidget);
    expect(find.text('Aktif Bertugas'), findsOneWidget);
    expect(find.text('Tugas Berjalan'), findsOneWidget);
    expect(find.text('Riwayat Pekerjaan'), findsOneWidget);

    // Verify empty state when no active task
    expect(find.textContaining('Belum ada tugas aktif saat ini'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/cleaner_dashboard_screen_test.dart`
Expected: FAIL (`cleaner_dashboard_screen.dart` does not exist).

- [ ] **Step 3: Implement `CleanerDashboardScreen`**

Create `mobile/lib/screens/cleaner_dashboard_screen.dart`:
- Profile Header (Avatar, Nama Cleaner, Badge 'Aktif Bertugas', Rating Bintang).
- Metric Cards (Tugas Aktif, Pekerjaan Selesai).
- DefaultTabController with TabBar: "Tugas Berjalan" & "Riwayat Pekerjaan".
- Card Tugas Aktif:
  - Info Hunian: Alamat, Patokan, Jadwal, Durasi, Luas Area.
  - Tombol Navigasi Peta (Google Maps intent via `url_launcher` with fallback).
  - Tombol Aksi Lapangan Bertahap (Menuju Lokasi $\rightarrow$ Tiba di Lokasi $\rightarrow$ Mulai Pengerjaan $\rightarrow$ Tuntaskan & Kirim Laporan Mutu).
  - Double-tap debouncing on state update.
- Empty state: Ilustrasi informatif jika tidak ada pesanan aktif.
- Menu Akun & Role Switcher modal trigger.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/cleaner_dashboard_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/cleaner_dashboard_screen.dart mobile/test/cleaner_dashboard_screen_test.dart
git commit -m "feat(mobile): add CleanerDashboardScreen with active task progression and empty state"
```

---

### Task 3: Smart Assignment Sheet (`SmartAssignmentSheet`)

**Files:**
- Create: `mobile/lib/widgets/smart_assignment_sheet.dart`
- Test: `mobile/test/smart_assignment_sheet_test.dart`

**Interfaces:**
- Consumes: `ApiService.fetchRecommendations`, `ApiService.assignCleaner`, `OrderModel`, `CleanerRecommendation`.
- Produces: `SmartAssignmentSheet` modal returning success boolean upon cleaner assignment.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/smart_assignment_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in/models/cleaner_model.dart';
import 'package:resik_in/models/order_model.dart';
import 'package:resik_in/widgets/smart_assignment_sheet.dart';

void main() {
  testWidgets('SmartAssignmentSheet displays recommendation list and disables conflicting cleaner', (WidgetTester tester) async {
    final order = OrderModel(
      id: 'ord-test-01',
      serviceId: 'srv-01',
      serviceName: 'Bersih Rumah',
      orderCode: 'RSK-20261005-001',
      alamatLengkap: 'Jl. Melati No. 12, Surabaya',
      patokanLokasi: 'Dekat Apotek',
      luasArea: 100,
      tanggalLayanan: '2026-10-05',
      startTime: '09:00',
      duration: 2,
      endTime: '11:00',
      hargaTotal: 150000,
      statusPekerjaan: 'Dikonfirmasi',
      statusPembayaran: 'Sudah Bayar',
      createdAt: '2026-10-04T10:00:00Z',
    );

    final recommendations = [
      CleanerRecommendation(
        cleaner: CleanerModel(
          id: 'cln-1',
          nama: 'Budi Santoso',
          rating: 4.9,
          totalSelesai: 45,
          statusOperasional: 'Aktif',
          keahlian: ['rumah', 'kos'],
          fotoUrl: '',
        ),
        score: 95.0,
        scoreBreakdown: {'ketersediaan': 40, 'keahlian': 30, 'rating': 15, 'pengalaman': 10},
        isPreferred: true,
        isAvailable: true,
      ),
      CleanerRecommendation(
        cleaner: CleanerModel(
          id: 'cln-2',
          nama: 'Candra Pratama',
          rating: 4.7,
          totalSelesai: 20,
          statusOperasional: 'Aktif',
          keahlian: ['rumah'],
          fotoUrl: '',
        ),
        score: 60.0,
        scoreBreakdown: {'ketersediaan': 0, 'keahlian': 30, 'rating': 15, 'pengalaman': 15},
        isPreferred: false,
        isAvailable: false, // Conflict
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartAssignmentSheet(
            order: order,
            recommendationsLoader: () async => recommendations,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penugasan Petugas Cerdas'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Pilihan Pelanggan'), findsOneWidget);
    expect(find.text('Candra Pratama'), findsOneWidget);
    expect(find.text('Jadwal Bentrok'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/smart_assignment_sheet_test.dart`
Expected: FAIL (`smart_assignment_sheet.dart` not found).

- [ ] **Step 3: Implement `SmartAssignmentSheet`**

Create `mobile/lib/widgets/smart_assignment_sheet.dart`:
- Header dengan informasi pesanan (Layanan, Waktu, Durasi).
- Daftar rekomendasi hasil Smart Matching (Score total %, Badge 'Pilihan Pelanggan', Badge 'Jadwal Bentrok').
- Tombol aksi 'Tugaskan Petugas' memanggil `ApiService.assignCleaner(order.id, cleaner.id)` dan pop `true`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/smart_assignment_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/smart_assignment_sheet.dart mobile/test/smart_assignment_sheet_test.dart
git commit -m "feat(mobile): add SmartAssignmentSheet with matching score and conflict badges"
```

---

### Task 4: Admin Operational Control Tower (`AdminDashboardScreen`)

**Files:**
- Create: `mobile/lib/screens/admin_dashboard_screen.dart`
- Test: `mobile/test/admin_dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `ApiService.fetchOrders`, `ApiService.updateOrderStatus`, `ApiService.reassignCleaner`, `ApiService.cancelOrder`, `SmartAssignmentSheet`.
- Produces: `AdminDashboardScreen` with pipeline counters, Tab 1 (Butuh Tindakan), Tab 2 (Monitoring Lapangan), Tab 3 (Tim Petugas), confirmation guard, reassign/cancel reason dialog.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/admin_dashboard_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in/models/order_model.dart';
import 'package:resik_in/models/user_model.dart';
import 'package:resik_in/screens/admin_dashboard_screen.dart';
import 'package:resik_in/services/auth_service.dart';

void main() {
  testWidgets('AdminDashboardScreen renders pipeline counters and tabs correctly', (WidgetTester tester) async {
    const admin = UserModel(
      id: 'usr-admin-001',
      nama: 'Admin Resik',
      email: 'admin@resik.in',
      role: 'admin',
    );
    AuthService.currentUserNotifier.value = admin;

    final dummyOrders = [
      OrderModel(
        id: 'ord-01',
        serviceId: 'srv-01',
        serviceName: 'Bersih Rumah',
        orderCode: 'RSK-20261005-001',
        alamatLengkap: 'Jl. Kertajaya Indah No. 10',
        patokanLokasi: 'Pagar Putih',
        luasArea: 80,
        tanggalLayanan: '2026-10-05',
        startTime: '09:00',
        duration: 2,
        endTime: '11:00',
        hargaTotal: 120000,
        statusPekerjaan: 'Menunggu Konfirmasi',
        statusPembayaran: 'Belum Bayar',
        createdAt: '2026-10-04T10:00:00Z',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          ordersLoader: () async => dummyOrders,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menara Kontrol Admin'), findsOneWidget);
    expect(find.text('Butuh Tindakan'), findsOneWidget);
    expect(find.text('Monitoring'), findsOneWidget);
    expect(find.text('Tim Petugas'), findsOneWidget);

    // Verify payment guard disabled button
    expect(find.text('Menunggu Pembayaran Pelanggan'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/admin_dashboard_screen_test.dart`
Expected: FAIL (`admin_dashboard_screen.dart` does not exist).

- [ ] **Step 3: Implement `AdminDashboardScreen`**

Create `mobile/lib/screens/admin_dashboard_screen.dart`:
- Pipeline Counter (Perlu Konfirmasi, Perlu Petugas, Sedang Berjalan, Tuntas, Dibatalkan).
- Tab 1: "Butuh Tindakan":
  - Pesanan `Menunggu Konfirmasi`: Jika `Sudah Bayar`, tombol "Konfirmasi Pesanan" aktif. Jika `Belum Bayar`, tombol terkunci dengan label "Menunggu Pembayaran Pelanggan" (*BR-FIN-001*).
  - Pesanan `Dikonfirmasi`: Tombol "Tugaskan Petugas" membuka `SmartAssignmentSheet`.
- Tab 2: "Monitoring":
  - Seluruh pesanan aktif lapangan.
  - Aksi "Ganti Petugas (*Reassign*)" dan "Batalkan Pesanan Darurat" dengan dialog input alasan minimal 5 karakter.
- Tab 3: "Tim Petugas":
  - Daftar cleaner dan status operasional.
- Header menu Akun & Role Switcher modal trigger.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/admin_dashboard_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/admin_dashboard_screen.dart mobile/test/admin_dashboard_screen_test.dart
git commit -m "feat(mobile): add AdminDashboardScreen with pipeline counters, tabs, and payment guard"
```

---

### Task 5: Customer UI Cleanup & Lifecycle-Aware Polling in `OrderTrackingScreen`

**Files:**
- Modify: `mobile/lib/constants.dart:34`
- Modify: `mobile/lib/screens/order_tracking_screen.dart:300-340`
- Test: `mobile/test/order_tracking_screen_test.dart`

**Interfaces:**
- Consumes: `AppConfig.kEnableOperationalSimulation`, `WidgetsBindingObserver`.
- Produces: Cleaned `OrderTrackingScreen` without floating simulation sheet, with 10s auto-polling while active, and cancellation upon dispose or terminal state.

- [ ] **Step 1: Write the failing test**

In `mobile/test/order_tracking_screen_test.dart`, add test asserting simulation sheet button is not rendered when simulation is disabled:
```dart
testWidgets('OrderTrackingScreen does not render Operational Simulation FAB when kEnableOperationalSimulation is false', (WidgetTester tester) async {
  final order = OrderModel(
    id: 'ord-test-cust',
    serviceId: 'srv-01',
    serviceName: 'Bersih Rumah',
    orderCode: 'RSK-20261005-001',
    alamatLengkap: 'Jl. Rungkut Asri Timur No. 5',
    patokanLokasi: 'Rumah Tingkat',
    luasArea: 120,
    tanggalLayanan: '2026-10-05',
    startTime: '09:00',
    duration: 2,
    endTime: '11:00',
    hargaTotal: 180000,
    statusPekerjaan: 'Menuju Lokasi',
    statusPembayaran: 'Sudah Bayar',
    createdAt: '2026-10-04T10:00:00Z',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: OrderTrackingScreen(
        orderId: order.id,
        initialOrder: order,
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Floating button Simulasi Operasional must NOT be present
  expect(find.text('Simulasi Operasional'), findsNothing);
  expect(find.byIcon(Icons.tune), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_tracking_screen_test.dart`
Expected: FAIL (button currently found because `kEnableOperationalSimulation = true`).

- [ ] **Step 3: Update `constants.dart` & `order_tracking_screen.dart`**

In `mobile/lib/constants.dart`:
```dart
class AppConfig {
  static const bool kEnableOperationalSimulation = false;
}
```

In `mobile/lib/screens/order_tracking_screen.dart`:
- Add `WidgetsBindingObserver` to `_OrderTrackingScreenState`.
- Add `Timer? _pollTimer` running every 10 seconds:
```dart
  void _initPollingTimer() {
    _pollTimer?.cancel();
    // Polling hanya aktif jika pesanan belum terminal
    if (_order != null && _order!.statusPekerjaan != 'Selesai' && _order!.statusPekerjaan != 'Dibatalkan') {
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted) {
          _fetchOrderSilently();
        }
      });
    }
  }
```
- In `didChangeAppLifecycleState`, cancel timer when paused, restart when resumed.
- In `dispose()`, cancel `_pollTimer`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/order_tracking_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/constants.dart mobile/lib/screens/order_tracking_screen.dart mobile/test/order_tracking_screen_test.dart
git commit -m "feat(mobile): remove simulation sheet and add lifecycle-aware short polling in OrderTrackingScreen"
```

---

### Task 6: Declarative `AuthGate` Multi-Role Routing & Thesis Role Switcher

**Files:**
- Create: `mobile/lib/widgets/role_switcher_sheet.dart`
- Modify: `mobile/lib/main.dart:36-51`
- Test: `mobile/test/auth_gate_role_test.dart`

**Interfaces:**
- Consumes: `UserModel.isAdmin`, `UserModel.isCleaner`, `UserModel.isCustomer`, `AuthService.currentUserNotifier`.
- Produces: Declarative routing to `AdminDashboardScreen`, `CleanerDashboardScreen`, or `HomeScreen`. `RoleSwitcherSheet` for examiners to test 3 roles.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/auth_gate_role_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in/main.dart';
import 'package:resik_in/models/user_model.dart';
import 'package:resik_in/screens/admin_dashboard_screen.dart';
import 'package:resik_in/screens/cleaner_dashboard_screen.dart';
import 'package:resik_in/services/auth_service.dart';

void main() {
  testWidgets('AuthGate routes to AdminDashboardScreen when user.role == admin', (WidgetTester tester) async {
    const admin = UserModel(
      id: 'usr-admin-01',
      nama: 'Admin Resik',
      email: 'admin@resik.in',
      role: 'admin',
    );
    AuthService.currentUserNotifier.value = admin;

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pumpAndSettle();

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
  });

  testWidgets('AuthGate routes to CleanerDashboardScreen when user.role == cleaner', (WidgetTester tester) async {
    const cleaner = UserModel(
      id: 'usr-cleaner-01',
      nama: 'Cecep',
      email: 'cecep@resik.in',
      role: 'cleaner',
      cleanerId: 'cln-01',
    );
    AuthService.currentUserNotifier.value = cleaner;

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pumpAndSettle();

    expect(find.byType(CleanerDashboardScreen), findsOneWidget);
  });

  testWidgets('AuthGate routes to HomeScreen when user.role == customer', (WidgetTester tester) async {
    const customer = UserModel(
      id: 'usr-customer-01',
      nama: 'Budi Santoso',
      email: 'budi@gmail.com',
      role: 'customer',
    );
    AuthService.currentUserNotifier.value = customer;

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth_gate_role_test.dart`
Expected: FAIL (`AuthGate` currently only returns `HomeScreen`).

- [ ] **Step 3: Implement `RoleSwitcherSheet` and update `AuthGate` in `main.dart`**

Create `mobile/lib/widgets/role_switcher_sheet.dart`:
Modal bottom sheet with 3 role choices:
1. "Pelanggan (Customer)" -> switches to `demoAccounts['customer']`.
2. "Petugas Kebersihan (Cleaner - Cecep)" -> switches to `demoAccounts['cleaner']` (with `cleanerId`).
3. "Administrator Operasional (Admin)" -> switches to `demoAccounts['admin']`.

In `mobile/lib/main.dart`, update `AuthGate`:
```dart
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        if (user != null) {
          if (user.isAdmin) {
            return AdminDashboardScreen(key: ValueKey('admin_${user.id}'));
          }
          if (user.isCleaner) {
            return CleanerDashboardScreen(key: ValueKey('cleaner_${user.id}'));
          }
          return HomeScreen(key: ValueKey('customer_${user.id}'));
        }
        return const WelcomeScreen();
      },
    );
  }
}
```
And in `HomeScreen` (Tab Akun), add tile/button to show `RoleSwitcherSheet`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auth_gate_role_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/role_switcher_sheet.dart mobile/lib/main.dart mobile/test/auth_gate_role_test.dart
git commit -m "feat(mobile): implement declarative role-based routing in AuthGate and RoleSwitcherSheet"
```

---

### Task 7: Full Test Suite Regression & Physical Device Verification

**Files:**
- Test All: Backend (`backend/test/`), Mobile (`mobile/test/`)

- [ ] **Step 1: Run Backend Test Suite**

Run: `cd backend && npm test`
Expected: 86 passing tests with 0 failures.

- [ ] **Step 2: Run Mobile Static Analysis**

Run: `cd mobile && flutter analyze`
Expected: 0 issues found.

- [ ] **Step 3: Run Mobile Test Suite**

Run: `cd mobile && flutter test`
Expected: All unit & widget tests pass (50+ tests).

- [ ] **Step 4: Build APK & Verify on Physical Device (Samsung Galaxy A52)**

Run: `adb devices`
Run: `adb reverse tcp:3000 tcp:3000`
Run: `flutter run -d <device_id>` or `flutter build apk`
Verify:
1. Login as Customer $\rightarrow$ Order cleaning $\rightarrow$ Pay simulation $\rightarrow$ OrderTrackingScreen.
2. Role Switcher to Admin $\rightarrow$ Admin Dashboard $\rightarrow$ Action Required $\rightarrow$ Konfirmasi $\rightarrow$ Assign Cecep.
3. Role Switcher to Cleaner $\rightarrow$ Cleaner Dashboard $\rightarrow$ Tugas Aktif $\rightarrow$ Menuju Lokasi $\rightarrow$ Tiba $\rightarrow$ Dikerjakan $\rightarrow$ Quality Report Before/After $\rightarrow$ Selesai.
4. Role Switcher to Customer $\rightarrow$ OrderTrackingScreen shows Selesai $\rightarrow$ View Quality Report $\rightarrow$ Submit Review.

- [ ] **Step 5: Commit Final Verification**

```bash
git commit --allow-empty -m "chore(release): verified multi-role dashboards end-to-end on test suites and physical device"
```
