import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/models/user_model.dart';
import 'package:resik_in_mobile/screens/admin_dashboard_screen.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

void main() {
  testWidgets('AdminDashboardScreen renders pipeline counters, tabs, and payment guard correctly', (WidgetTester tester) async {
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
        alamatLengkap: 'Jl. Kertajaya Indah No. 10, Surabaya',
        patokanLokasi: 'Pagar Putih',
        luasArea: '80',
        tanggalLayanan: '2026-10-05',
        startTime: '09:00',
        duration: 2,
        endTime: '11:00',
        hargaSaatBooking: 120000,
        totalBiaya: 120000,
        statusPekerjaan: 'Menunggu Konfirmasi',
        statusPembayaran: 'Belum Bayar', // Unpaid guard
        createdAt: '2026-10-04T10:00:00Z',
      ),
      OrderModel(
        id: 'ord-02',
        serviceId: 'srv-02',
        serviceName: 'Bersih Kos',
        orderCode: 'RSK-20261005-002',
        alamatLengkap: 'Jl. Gebang Wetan No. 3, Surabaya',
        patokanLokasi: 'Dekat Warung Madura',
        luasArea: '25',
        tanggalLayanan: '2026-10-05',
        startTime: '13:00',
        duration: 2,
        endTime: '15:00',
        hargaSaatBooking: 75000,
        totalBiaya: 75000,
        statusPekerjaan: 'Dikonfirmasi',
        statusPembayaran: 'Sudah Bayar',
        createdAt: '2026-10-04T11:00:00Z',
      ),
    ];

    final dummyCleaners = [
      CleanerModel(
        id: 'cln-01',
        nama: 'Cecep',
        ratingRataRata: 5.0,
        totalUlasan: 12,
        totalPekerjaan: 15,
        pengalamanTahun: 3,
        tingkatKepuasan: 100,
        ketepatanWaktu: 100,
        statusOperasional: 'Aktif',
        keahlian: ['rumah', 'kos'],
        sertifikasi: [],
        ulasan: [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          ordersLoader: () async => dummyOrders,
          cleanersLoader: () async => dummyCleaners,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menara Kontrol Admin'), findsOneWidget);
    expect(find.text('Butuh Tindakan'), findsOneWidget);
    expect(find.text('Monitoring'), findsOneWidget);
    expect(find.text('Tim Petugas'), findsOneWidget);

    // Verify payment guard disabled button for unpaid order
    expect(find.text('Menunggu Pembayaran Pelanggan'), findsOneWidget);

    // Verify confirmed order has assign button
    expect(find.text('Tugaskan Petugas'), findsOneWidget);
  });
}
