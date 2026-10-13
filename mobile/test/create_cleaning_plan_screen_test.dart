import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/service_model.dart';
import 'package:resik_in_mobile/screens/create_cleaning_plan_screen.dart';

void main() {
  final dummyService = ServiceModel(
    id: 'srv-002-kos',
    namaLayanan: 'Pembersihan Kos',
    kategori: 'kos',
    deskripsi: 'Pembersihan kamar kos teratur dan higienis',
    durasiEstimasi: '1 - 2 Jam',
    tarifDasar: 50000.0,
    iconName: 'cleaning_services',
    isActive: true,
  );

  testWidgets('1. CreateCleaningPlanScreen menampilkan form lengkap pendaftaran paket rutin', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: CreateCleaningPlanScreen(service: dummyService, initialCleaners: const []),
      ),
    );

    // Verifikasi Header & Info Layanan
    expect(find.text('Langganan Kebersihan Rutin'), findsOneWidget);
    expect(find.text('Pembersihan Kos'), findsOneWidget);

    // Verifikasi Komponen Form
    expect(find.byKey(const Key('input_nama_paket')), findsOneWidget);
    expect(find.byKey(const Key('choice_freq_mingguan')), findsOneWidget);
    expect(find.byKey(const Key('choice_freq_dua_mingguan')), findsOneWidget);
    expect(find.byKey(const Key('dropdown_hari')), findsOneWidget);
    expect(find.byKey(const Key('input_jam_mulai')), findsOneWidget);
    expect(find.byKey(const Key('input_alamat_lengkap')), findsOneWidget);
    expect(find.byKey(const Key('input_patokan_lokasi')), findsOneWidget);
    expect(find.byKey(const Key('btn_submit_cleaning_plan')), findsOneWidget);
  });

  testWidgets('2. Validasi form menolak submit jika nama paket atau alamat terlalu pendek', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: CreateCleaningPlanScreen(service: dummyService, initialCleaners: const []),
      ),
    );

    // Masukkan data tidak valid
    await tester.enterText(find.byKey(const Key('input_nama_paket')), 'A');
    await tester.enterText(find.byKey(const Key('input_alamat_lengkap')), 'Jl. Baru');
    await tester.enterText(find.byKey(const Key('input_patokan_lokasi')), 'D');
    await tester.pump();

    // Tap submit
    final submitBtn = find.byKey(const Key('btn_submit_cleaning_plan'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pump();

    // Verifikasi pesan validasi muncul
    expect(find.textContaining('minimal 10 karakter'), findsOneWidget);
    expect(find.textContaining('minimal 3 karakter'), findsWidgets);
  });

  testWidgets('3. Pilihan frekuensi dapat diubah secara interaktif', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: CreateCleaningPlanScreen(service: dummyService, initialCleaners: const []),
      ),
    );

    // Awalnya default frekuensi adalah mingguan
    final duaMingguanChip = find.byKey(const Key('choice_freq_dua_mingguan'));
    await tester.tap(duaMingguanChip);
    await tester.pump();

    // Memastikan chip dua mingguan ter-tap tanpa error
    expect(find.text('Setiap 2 Minggu'), findsWidgets);
  });
}
