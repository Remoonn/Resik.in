import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/models/user_model.dart';
import 'package:resik_in_mobile/screens/cleaner_dashboard_screen.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

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

  testWidgets('CleanerDashboardScreen renders active order and sequential action buttons', (WidgetTester tester) async {
    const cleaner = UserModel(
      id: 'usr-cleaner-001',
      nama: 'Cecep Cleaner',
      email: 'cecep@resik.in',
      role: 'cleaner',
      cleanerId: 'cln-001',
    );
    AuthService.currentUserNotifier.value = cleaner;

    final activeOrder = OrderModel(
      id: 'ord-cleaner-test-01',
      serviceId: 'srv-01',
      serviceName: 'Bersih Rumah',
      orderCode: 'RSK-20261005-001',
      alamatLengkap: 'Jl. Rungkut Madya No. 99, Surabaya',
      patokanLokasi: 'Dekat Kampus UPN',
      luasArea: '100',
      tanggalLayanan: '2026-10-05',
      startTime: '09:00',
      duration: 2,
      endTime: '11:00',
      hargaSaatBooking: 150000,
      totalBiaya: 150000,
      statusPekerjaan: 'Petugas Ditugaskan',
      statusPembayaran: 'Sudah Bayar',
      cleanerId: 'cln-001',
      createdAt: '2026-10-04T10:00:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CleanerDashboardScreen(
          ordersLoader: () async => [activeOrder],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bersih Rumah'), findsOneWidget);
    expect(find.text('RSK-20261005-001'), findsOneWidget);
    expect(find.textContaining('Jl. Rungkut Madya'), findsOneWidget);
    // Button for 'Petugas Ditugaskan' -> 'Mulai Berangkat (Menuju Lokasi)'
    expect(find.text('Mulai Berangkat (Menuju Lokasi)'), findsOneWidget);
    expect(find.text('Navigasi Peta'), findsOneWidget);
  });

  testWidgets('CleanerDashboardScreen renders Tuntaskan & Buat Laporan Mutu and opens QualityReportFormSheet', (WidgetTester tester) async {
    const cleaner = UserModel(
      id: 'usr-cleaner-001',
      nama: 'Cecep Cleaner',
      email: 'cecep@resik.in',
      role: 'cleaner',
      cleanerId: 'cln-001',
    );
    AuthService.currentUserNotifier.value = cleaner;

    final inProgressOrder = OrderModel(
      id: 'ord-cleaner-in-progress',
      serviceId: 'srv-01',
      serviceName: 'Bersih Rumah',
      orderCode: 'RSK-20261005-002',
      alamatLengkap: 'Jl. Rungkut Madya No. 99, Surabaya',
      patokanLokasi: 'Dekat Kampus UPN',
      luasArea: '100',
      tanggalLayanan: '2026-10-05',
      startTime: '09:00',
      duration: 2,
      endTime: '11:00',
      hargaSaatBooking: 150000,
      totalBiaya: 150000,
      statusPekerjaan: 'Sedang Dikerjakan',
      statusPembayaran: 'Sudah Bayar',
      cleanerId: 'cln-001',
      createdAt: '2026-10-04T10:00:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CleanerDashboardScreen(
          ordersLoader: () async => [inProgressOrder],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tuntaskan & Buat Laporan Mutu'), findsOneWidget);

    // Tap the button to open QualityReportFormSheet
    await tester.tap(find.text('Tuntaskan & Buat Laporan Mutu'));
    await tester.pumpAndSettle();

    // Verify QualityReportFormSheet is displayed
    expect(find.text('Laporan Mutu Hasil Kerja'), findsOneWidget);
    expect(find.text('Kirim Laporan Mutu & Selesaikan'), findsOneWidget);
  });
}

