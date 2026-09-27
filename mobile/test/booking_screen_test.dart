import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/service_model.dart';
import 'package:resik_in_mobile/screens/booking_screen.dart';

void main() {
  final dummyService = ServiceModel(
    id: 'srv-001-rumah',
    namaLayanan: 'Pembersihan Rumah',
    kategori: 'rumah',
    deskripsi: 'Pembersihan hunian menyeluruh untuk keluarga',
    durasiEstimasi: '2 - 3 Jam',
    tarifDasar: 120000.0,
    iconName: 'home',
    isActive: true,
  );

  testWidgets('1. BookingScreen menampilkan informasi layanan dan form pemesanan', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: BookingScreen(service: dummyService),
      ),
    );

    // Verifikasi Header Layanan
    expect(find.text('Pembersihan Rumah'), findsOneWidget);
    expect(find.textContaining('120.000'), findsOneWidget);

    // Verifikasi Input Form Wajib
    expect(find.byKey(const Key('input_alamat_lengkap')), findsOneWidget);
    expect(find.byKey(const Key('input_patokan_lokasi')), findsOneWidget);
    expect(find.byKey(const Key('input_luas_area')), findsOneWidget);
    expect(find.byKey(const Key('btn_submit_booking')), findsOneWidget);
  });

  testWidgets('2. Validasi form gagal jika alamat dan patokan terlalu pendek', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: BookingScreen(service: dummyService),
      ),
    );

    // Isi alamat terlalu pendek (< 10 karakter) dan patokan (< 3 karakter)
    await tester.enterText(find.byKey(const Key('input_alamat_lengkap')), 'Jl. Baru');
    await tester.enterText(find.byKey(const Key('input_patokan_lokasi')), 'Ok');
    await tester.pump();

    // Tekan tombol submit
    final submitBtn = find.byKey(const Key('btn_submit_booking'));
    await tester.tap(submitBtn);
    await tester.pump();

    // Verifikasi pesan validasi muncul
    expect(find.textContaining('minimal 10 karakter'), findsOneWidget);
    expect(find.textContaining('minimal 3 karakter'), findsOneWidget);
  });

  testWidgets('3. BookingScreen menampilkan bagian Rekomendasi Petugas (Smart Matching)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: BookingScreen(service: dummyService),
      ),
    );
    await tester.pump();

    // Verifikasi section smart matching ada
    expect(find.textContaining('Rekomendasi Petugas'), findsOneWidget);
    expect(find.text('Pilihkan Otomatis oleh Admin'), findsOneWidget);
  });
}
