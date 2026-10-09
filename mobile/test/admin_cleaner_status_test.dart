import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/screens/admin_dashboard_screen.dart';

void main() {
  testWidgets('AdminDashboardScreen displays cleaners tab and opens change status bottom sheet', (WidgetTester tester) async {
    final cleaners = [
      CleanerModel(
        id: 'cln-1',
        nama: 'Budi Santoso',
        ratingRataRata: 4.9,
        totalUlasan: 45,
        totalPekerjaan: 50,
        pengalamanTahun: 3,
        tingkatKepuasan: 98,
        ketepatanWaktu: 100,
        statusOperasional: 'Aktif',
        keahlian: ['rumah', 'kos'],
        sertifikasi: [],
        ulasan: [],
      ),
      CleanerModel(
        id: 'cln-2',
        nama: 'Candra Pratama',
        ratingRataRata: 4.7,
        totalUlasan: 30,
        totalPekerjaan: 35,
        pengalamanTahun: 2,
        tingkatKepuasan: 95,
        ketepatanWaktu: 95,
        statusOperasional: 'Cuti',
        keahlian: ['kantor'],
        sertifikasi: [],
        ulasan: [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          ordersLoader: () async => <OrderModel>[],
          cleanersLoader: () async => cleaners,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pindah ke tab Tim Petugas
    await tester.tap(find.text('Tim Petugas'));
    await tester.pumpAndSettle();

    // Pastikan daftar cleaner muncul
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Candra Pratama'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Cuti'), findsOneWidget);

    // Tekan tombol Status pada Budi Santoso
    final statusButtons = find.widgetWithText(OutlinedButton, 'Status');
    expect(statusButtons, findsNWidgets(2));
    await tester.tap(statusButtons.first);
    await tester.pumpAndSettle();

    // Modal Kelola Status Petugas harus muncul
    expect(find.text('Kelola Status Petugas'), findsOneWidget);
    expect(find.text('Aktif (Siap Kerja)'), findsOneWidget);
    expect(find.text('Cuti (Libur Sementara)'), findsOneWidget);
    expect(find.text('Nonaktif (Berhenti)'), findsOneWidget);
    expect(find.text('Simpan Perubahan Status'), findsOneWidget);
  });
}
