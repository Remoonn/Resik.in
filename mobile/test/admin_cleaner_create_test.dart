import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/screens/admin_dashboard_screen.dart';

void main() {
  testWidgets('AdminDashboardScreen allows opening and validating new cleaner registration form', (WidgetTester tester) async {
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

    // Tombol Tambah Petugas harus muncul di header dan/atau FAB
    expect(find.byKey(const Key('admin_header_add_cleaner_btn')), findsOneWidget);
    expect(find.byKey(const Key('admin_fab_add_cleaner')), findsOneWidget);

    // Buka formulir pendaftaran melalui tombol header
    await tester.tap(find.byKey(const Key('admin_header_add_cleaner_btn')));
    await tester.pumpAndSettle();

    // Pastikan elemen formulir muncul
    expect(find.text('Pendaftaran Petugas Baru'), findsOneWidget);
    expect(find.byKey(const Key('picker_cleaner_photo')), findsOneWidget);
    expect(find.text('Pilih Foto'), findsOneWidget);
    expect(find.textContaining('Akun Login Otomatis'), findsOneWidget);
    expect(find.byKey(const Key('input_cleaner_nama')), findsOneWidget);
    expect(find.byKey(const Key('input_cleaner_kontak')), findsOneWidget);
    expect(find.byKey(const Key('btn_submit_create_cleaner')), findsOneWidget);

    // Coba submit saat input masih kosong -> trigger validation
    await tester.ensureVisible(find.byKey(const Key('btn_submit_create_cleaner')));
    await tester.tap(find.byKey(const Key('btn_submit_create_cleaner')));
    await tester.pumpAndSettle();

    expect(find.text('Nama wajib diisi minimal 3 karakter'), findsOneWidget);
    expect(find.text('Nomor kontak minimal 8 digit'), findsOneWidget);

    // Masukkan data nama dan kontak
    await tester.enterText(find.byKey(const Key('input_cleaner_nama')), 'Rian Kurniawan');
    await tester.enterText(find.byKey(const Key('input_cleaner_kontak')), '081234567890');
    await tester.pumpAndSettle();

    // Pilih filter chip keahlian
    expect(find.byKey(const Key('skill_chip_rumah')), findsOneWidget);
    expect(find.byKey(const Key('skill_chip_kos')), findsOneWidget);
  });
}
