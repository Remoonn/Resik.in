import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/main.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/models/user_model.dart';
import 'package:resik_in_mobile/screens/order_tracking_screen.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

void main() {
  testWidgets('1. OrderTrackingScreen menampilkan badge Sesi Langganan saat order memiliki cleaningPlanId', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final planOrder = OrderModel(
      id: 'ord-plan-001',
      orderCode: 'RSK-20261019-001',
      serviceId: 'srv-002',
      serviceName: 'Pembersihan Kos Rutin',
      tanggalLayanan: '2026-10-19',
      startTime: '09:00',
      endTime: '11:00',
      duration: 2,
      alamatLengkap: 'Jl. Kaliurang KM 14.5 No. 4',
      patokanLokasi: 'Pagar hitam dekat warung',
      luasArea: '1 Kamar Kos',
      hargaSaatBooking: 100000.0,
      totalBiaya: 100000.0,
      statusPembayaran: 'Sudah Bayar',
      statusPekerjaan: 'Menunggu Konfirmasi',
      cleaningPlanId: 'plan-001',
      sessionNumber: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          orderId: planOrder.id,
          initialOrder: planOrder,
        ),
      ),
    );
    await tester.pump();

    // Verifikasi badge sesi langganan muncul
    expect(find.text('Sesi Langganan #3'), findsOneWidget);
    expect(find.byIcon(Icons.autorenew_rounded), findsWidgets);
  });

  testWidgets('2. HomeScreen menampilkan banner Paket Langganan Bersih dan dapat di-tap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();

    final banner = find.byKey(const Key('banner_cleaning_plan'));
    expect(banner, findsOneWidget);
    expect(find.text('Paket Langganan Bersih'), findsOneWidget);

    await tester.tap(banner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('3. Modal profil pelanggan menampilkan menu Paket Langganan Saya', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      AuthService.currentUserNotifier.value = null;
    });

    AuthService.currentUserNotifier.value = UserModel(
      id: 'cust-101',
      email: 'customer@resik.in',
      nama: 'Budi Santoso',
      role: 'customer',
      nomorWa: '081234567890',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();

    final profileChip = find.byKey(const Key('appbar_profile_chip'));
    expect(profileChip, findsOneWidget);

    await tester.tap(profileChip);
    await tester.pumpAndSettle();

    final planMenu = find.byKey(const Key('session_cleaning_plans_button'));
    expect(planMenu, findsOneWidget);
    expect(find.text('Paket Langganan Saya'), findsOneWidget);
  });
}
