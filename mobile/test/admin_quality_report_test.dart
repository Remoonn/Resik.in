import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/models/user_model.dart';
import 'package:resik_in_mobile/screens/admin_dashboard_screen.dart';
import 'package:resik_in_mobile/screens/quality_report_screen.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService.currentUserNotifier.value = const UserModel(
      id: 'usr-admin-001',
      nama: 'Admin Resik',
      email: 'admin@resik.in',
      role: 'admin',
    );
  });

  final dummyCleaners = [
    CleanerModel(
      id: 'cln-01',
      nama: 'Cecep Supriyadi',
      ratingRataRata: 4.9,
      totalUlasan: 10,
      totalPekerjaan: 15,
      pengalamanTahun: 3,
      tingkatKepuasan: 98,
      ketepatanWaktu: 100,
      statusOperasional: 'Aktif',
      keahlian: ['rumah', 'kos'],
      sertifikasi: [],
      ulasan: [],
    ),
  ];

  final dummyOrders = [
    OrderModel(
      id: 'ord-berjalan-1',
      serviceId: 'srv-01',
      serviceName: 'Bersih Rumah Reguler',
      orderCode: 'RSK-20261005-001',
      cleanerId: 'cln-01',
      alamatLengkap: 'Jl. Pemuda No. 12, Surabaya',
      patokanLokasi: 'Depan Pos Satpam',
      luasArea: '60',
      tanggalLayanan: '2026-10-05',
      startTime: '08:00',
      duration: 2,
      endTime: '10:00',
      hargaSaatBooking: 100000,
      totalBiaya: 100000,
      statusPekerjaan: 'Sedang Dikerjakan',
      statusPembayaran: 'Sudah Bayar',
    ),
    OrderModel(
      id: 'ord-selesai-1',
      serviceId: 'srv-02',
      serviceName: 'Bersih Kamar Kos',
      orderCode: 'RSK-20261005-002',
      cleanerId: 'cln-01',
      alamatLengkap: 'Jl. Gebang Wetan No. 3, Surabaya',
      patokanLokasi: 'Pagar Hijau',
      luasArea: '20',
      tanggalLayanan: '2026-10-05',
      startTime: '10:30',
      duration: 1,
      endTime: '11:30',
      hargaSaatBooking: 50000,
      totalBiaya: 50000,
      statusPekerjaan: 'Selesai',
      statusPembayaran: 'Sudah Bayar',
    ),
    OrderModel(
      id: 'ord-batal-1',
      serviceId: 'srv-03',
      serviceName: 'Bersih Kantor',
      orderCode: 'RSK-20261005-003',
      cleanerId: 'cln-01',
      alamatLengkap: 'Jl. Basuki Rahmat No. 45, Surabaya',
      patokanLokasi: 'Lantai 2',
      luasArea: '100',
      tanggalLayanan: '2026-10-05',
      startTime: '14:00',
      duration: 3,
      endTime: '17:00',
      hargaSaatBooking: 250000,
      totalBiaya: 250000,
      statusPekerjaan: 'Dibatalkan',
      statusPembayaran: 'Sudah Bayar',
      cancellationReason: 'Permintaan pelanggan mendadak',
    ),
  ];

  testWidgets('Monitoring tab displays filter bar and completed order card with quality report inspection button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          ordersLoader: () async => dummyOrders,
          cleanersLoader: () async => dummyCleaners,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Monitoring Tab
    await tester.tap(find.text('Monitoring'));
    await tester.pumpAndSettle();

    // Verify filter chips exist
    expect(find.byKey(const Key('filter_monitoring_aktif')), findsOneWidget);
    expect(find.byKey(const Key('filter_monitoring_selesai')), findsOneWidget);
    expect(find.byKey(const Key('filter_monitoring_batal')), findsOneWidget);

    // Default filter is 'aktif' -> displays ongoing order
    expect(find.text('Bersih Rumah Reguler'), findsOneWidget);
    expect(find.text('Sedang Dikerjakan'), findsOneWidget);
    expect(find.text('Petugas: Cecep Supriyadi'), findsOneWidget);

    // Switch to 'selesai' filter
    await tester.tap(find.byKey(const Key('filter_monitoring_selesai')));
    await tester.pumpAndSettle();

    // Verify completed order card
    expect(find.text('Bersih Kamar Kos'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Cecep Supriyadi'), findsOneWidget);
    expect(find.text('Petugas Pelaksana'), findsOneWidget);

    // Verify "Lihat Laporan Mutu" button exists
    final qrButton = find.byKey(const Key('btn_admin_view_qr_ord-selesai-1'));
    expect(qrButton, findsOneWidget);
    expect(find.text('Lihat Laporan Mutu'), findsOneWidget);

    // Tap "Lihat Laporan Mutu" and verify navigation to QualityReportScreen
    await tester.tap(qrButton);
    await tester.pumpAndSettle();

    expect(find.byType(QualityReportScreen), findsOneWidget);
  });

  testWidgets('Monitoring tab displays cancelled order with cancellation reason', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          ordersLoader: () async => dummyOrders,
          cleanersLoader: () async => dummyCleaners,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Monitoring Tab
    await tester.tap(find.text('Monitoring'));
    await tester.pumpAndSettle();

    // Switch to 'batal' filter
    await tester.tap(find.byKey(const Key('filter_monitoring_batal')));
    await tester.pumpAndSettle();

    // Verify cancelled order card
    expect(find.text('Bersih Kantor'), findsOneWidget);
    expect(find.text('Dibatalkan'), findsNWidgets(2)); // Filter chip & status badge
    expect(find.text('Alasan: Permintaan pelanggan mendadak'), findsOneWidget);
  });

  testWidgets('Tapping pipeline counter chip navigates to relevant tab and filter', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          ordersLoader: () async => dummyOrders,
          cleanersLoader: () async => dummyCleaners,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Currently on tab 0 (Butuh Tindakan)
    // Tap chip "⚪ Tuntas"
    await tester.tap(find.byKey(const Key('counter_chip_tuntas')));
    await tester.pumpAndSettle();

    // Should have transitioned to tab 1 and selected 'selesai'
    expect(find.text('Bersih Kamar Kos'), findsOneWidget);
    expect(find.text('Lihat Laporan Mutu'), findsOneWidget);
  });
}
