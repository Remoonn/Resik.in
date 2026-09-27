import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/screens/cleaner_detail_screen.dart';

void main() {
  final sampleCleaner = CleanerModel(
    id: 'cln-001',
    nama: 'Candra Pratama',
    nomorKontak: '081234567801',
    fotoUrl: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400',
    keahlian: ['pasca_renovasi', 'rumah', 'kantor'],
    pengalamanTahun: 4,
    ratingRataRata: 4.9,
    totalUlasan: 127,
    totalPekerjaan: 142,
    tingkatKepuasan: 99,
    ketepatanWaktu: 98,
    statusOperasional: 'Aktif',
    tentang: 'Spesialis pembersihan mendalam (deep cleaning) dan pasca renovasi.',
    sertifikasi: ['Sertifikasi BNSP K3 Kebersihan', 'Vaksinasi Lengkap'],
    ulasan: [
      CleanerReviewModel(
        id: 'rev-001',
        cleanerId: 'cln-001',
        customerNama: 'Anisa Rahmawati',
        rating: 5,
        tanggal: '2026-09-20',
        ulasan: 'Pekerjaan Mas Candra sangat bersih dan rapi!',
        serviceNama: 'Pembersihan Pasca Renovasi',
      )
    ],
  );

  final provisionalCleaner = CleanerModel(
    id: 'cln-005',
    nama: 'Dewi Lestari',
    keahlian: ['rumah', 'kos'],
    pengalamanTahun: 1,
    ratingRataRata: 0.0,
    totalUlasan: 0,
    totalPekerjaan: 0,
    tingkatKepuasan: 100,
    ketepatanWaktu: 100,
    statusOperasional: 'Aktif',
    tentang: 'Petugas kebersihan baru akademi Resik.in.',
    sertifikasi: ['Kelulusan Akademi Resik.in 2026'],
    ulasan: [],
  );

  Widget createWidgetUnderTest(CleanerModel cleaner, {bool isProvisional = false}) {
    return MaterialApp(
      home: CleanerDetailScreen(
        cleaner: cleaner,
        isProvisionalRating: isProvisional,
      ),
    );
  }

  testWidgets('TC-SCR3-01: Menampilkan profil lengkap petugas dan metrik performa', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(sampleCleaner));

    expect(find.text('Candra Pratama'), findsWidgets);
    expect(find.text('4 Tahun Pengalaman'), findsOneWidget);
    expect(find.text('142'), findsOneWidget); // Pekerjaan selesai
    expect(find.text('99%'), findsOneWidget); // Kepuasan
    expect(find.text('98%'), findsOneWidget); // Ketepatan waktu
    expect(find.text('Anisa Rahmawati'), findsOneWidget); // Ulasan pelanggan
    expect(find.text('Pilih Petugas Ini'), findsOneWidget);
  });

  testWidgets('TC-SCR3-02: Menampilkan badge transparansi rating awal untuk petugas baru', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(provisionalCleaner, isProvisional: true));

    expect(find.text('Dewi Lestari'), findsWidgets);
    expect(find.textContaining('Petugas Baru'), findsWidgets);
    expect(find.textContaining('Rating Awal 4.5'), findsWidgets);
  });

  testWidgets('TC-SCR3-03: Menekan tombol Pilih Petugas Ini menutup layar dengan hasil cleaner', (WidgetTester tester) async {
    CleanerModel? selectedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              selectedResult = await Navigator.push<CleanerModel>(
                context,
                MaterialPageRoute(
                  builder: (context) => CleanerDetailScreen(cleaner: sampleCleaner),
                ),
              );
            },
            child: const Text('Open Profile'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Petugas Ini'), findsOneWidget);
    await tester.tap(find.text('Pilih Petugas Ini'));
    await tester.pumpAndSettle();

    expect(selectedResult, isNotNull);
    expect(selectedResult!.id, 'cln-001');
  });
}
