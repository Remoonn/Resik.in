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

  testWidgets('AdminDashboardScreen displays preferred cleaner badge and 1-click assign button for customer choice', (WidgetTester tester) async {
    final orderWithPref = OrderModel(
      id: 'ord-pref-01',
      serviceId: 'srv-02',
      serviceName: 'Pembersihan Kos',
      orderCode: 'RSK-20261008-069',
      alamatLengkap: 'Jl. Durian no 79',
      patokanLokasi: 'Pagar Putih',
      luasArea: '20',
      tanggalLayanan: '2026-10-08',
      startTime: '11:00',
      duration: 2,
      endTime: '13:00',
      hargaSaatBooking: 75000,
      totalBiaya: 75000,
      statusPekerjaan: 'Dikonfirmasi',
      statusPembayaran: 'Sudah Bayar',
      preferensiPetugasId: 'cln-siti',
      createdAt: '2026-10-08T08:00:00Z',
    );

    final cleaners = [
      CleanerModel(
        id: 'cln-siti',
        nama: 'Siti Aminah',
        ratingRataRata: 4.8,
        totalUlasan: 20,
        totalPekerjaan: 25,
        pengalamanTahun: 5,
        tingkatKepuasan: 98,
        ketepatanWaktu: 95,
        statusOperasional: 'Aktif',
        keahlian: ['kos', 'rumah'],
        sertifikasi: [],
        ulasan: [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          ordersLoader: () async => [orderWithPref],
          cleanersLoader: () async => cleaners,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify preference badge
    expect(find.textContaining('Pilihan Pelanggan:'), findsOneWidget);
    expect(find.textContaining('Siti Aminah'), findsWidgets);

    // Verify 1-click assign button
    expect(find.text('Tugaskan Siti Aminah (Pilihan Pelanggan)'), findsOneWidget);
    expect(find.text('Ganti / Pilih Petugas Lain'), findsOneWidget);
  });
}
