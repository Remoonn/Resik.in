import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaning_plan_model.dart';
import 'package:resik_in_mobile/screens/cleaning_plans_screen.dart';

void main() {
  final dummyPlan1 = CleaningPlanModel(
    id: 'plan-001',
    customerId: 'usr-001',
    planName: 'Langganan Bersih Kos Mahasiswa',
    serviceCategory: 'kos',
    serviceId: 'srv-002',
    frequency: 'mingguan',
    dayOfWeek: 1,
    dayName: 'Senin',
    startTime: '09:00',
    duration: 2,
    pricePerSession: 100000.0,
    address: 'Jl. Kaliurang KM 14.5 No. 4',
    status: 'Aktif',
    nextSessionDate: '2026-10-19',
    totalSessionsCompleted: 2,
    preferredCleaner: CleaningPlanCleanerInfo(
      id: 'cln-001',
      nama: 'Siti Rahmawati',
      ratingRataRata: 4.9,
      totalPekerjaan: 40,
    ),
  );

  final dummyPlan2 = CleaningPlanModel(
    id: 'plan-002',
    customerId: 'usr-001',
    planName: 'Rutin Rumah 2 Mingguan',
    serviceCategory: 'rumah',
    serviceId: 'srv-001',
    frequency: 'dua_mingguan',
    dayOfWeek: 6,
    dayName: 'Sabtu',
    startTime: '10:00',
    duration: 3,
    pricePerSession: 180000.0,
    address: 'Perumahan Sleman Asri B-3',
    status: 'Dijeda',
    nextSessionDate: '2026-10-24',
    totalSessionsCompleted: 0,
  );

  testWidgets('1. CleaningPlansScreen menampilkan daftar kartu langganan dengan detail lengkap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: CleaningPlansScreen(
          initialPlans: [dummyPlan1, dummyPlan2],
        ),
      ),
    );

    // Verifikasi Header
    expect(find.text('Paket Langganan Saya'), findsOneWidget);

    // Verifikasi Kartu Plan 1 (Aktif)
    expect(find.text('Langganan Bersih Kos Mahasiswa'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.textContaining('Senin, 09:00'), findsOneWidget);
    expect(find.textContaining('Siti Rahmawati'), findsOneWidget);
    expect(find.textContaining('2 Sesi Selesai'), findsOneWidget);
    expect(find.textContaining('2026-10-19'), findsOneWidget);

    // Verifikasi Kartu Plan 2 (Dijeda)
    expect(find.text('Rutin Rumah 2 Mingguan'), findsOneWidget);
    expect(find.text('Dijeda'), findsOneWidget);
  });

  testWidgets('2. Menampilkan aksi Jeda dan tombol pemicu sesi berikutnya', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: CleaningPlansScreen(
          initialPlans: [dummyPlan1],
        ),
      ),
    );

    // Verifikasi tombol-tombol aksi ada pada kartu aktif
    expect(find.byKey(const Key('btn_toggle_status_plan_001')), findsOneWidget);
    expect(find.byKey(const Key('btn_trigger_next_session_plan_001')), findsOneWidget);
    expect(find.text('Jadwalkan Sesi Sekarang'), findsOneWidget);
  });

  testWidgets('3. Menampilkan state kosong saat tidak memiliki paket langganan', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: CleaningPlansScreen(
          initialPlans: [],
        ),
      ),
    );

    expect(find.text('Belum Ada Paket Langganan'), findsOneWidget);
    expect(find.text('Daftar Layanan Rutin'), findsOneWidget);
  });
}
