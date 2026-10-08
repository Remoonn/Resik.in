import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/widgets/smart_assignment_sheet.dart';

void main() {
  testWidgets('SmartAssignmentSheet displays recommendation list and disables conflicting cleaner', (WidgetTester tester) async {
    final order = OrderModel(
      id: 'ord-test-01',
      serviceId: 'srv-01',
      serviceName: 'Bersih Rumah',
      orderCode: 'RSK-20261005-001',
      alamatLengkap: 'Jl. Melati No. 12, Surabaya',
      patokanLokasi: 'Dekat Apotek',
      luasArea: '100',
      tanggalLayanan: '2026-10-05',
      startTime: '09:00',
      duration: 2,
      endTime: '11:00',
      hargaSaatBooking: 150000,
      totalBiaya: 150000,
      statusPekerjaan: 'Dikonfirmasi',
      statusPembayaran: 'Sudah Bayar',
      preferensiPetugasId: 'cln-1',
      createdAt: '2026-10-04T10:00:00Z',
    );

    final recommendations = [
      CleanerRecommendation(
        cleaner: CleanerModel(
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
        score: CleanerScoreModel(
          skillScore: 30,
          availScore: 40,
          ratingScore: 15,
          effectiveRating: 4.9,
          isProvisionalRating: false,
          expScore: 10,
          totalScore: 95.0,
          matchBadge: 'Pilihan Pelanggan',
        ),
      ),
      CleanerRecommendation(
        cleaner: CleanerModel(
          id: 'cln-2',
          nama: 'Candra Pratama',
          ratingRataRata: 4.7,
          totalUlasan: 20,
          totalPekerjaan: 25,
          pengalamanTahun: 2,
          tingkatKepuasan: 95,
          ketepatanWaktu: 90,
          statusOperasional: 'Aktif',
          keahlian: ['rumah'],
          sertifikasi: [],
          ulasan: [],
        ),
        score: CleanerScoreModel(
          skillScore: 30,
          availScore: 0, // Bentrok
          ratingScore: 15,
          effectiveRating: 4.7,
          isProvisionalRating: false,
          expScore: 15,
          totalScore: 60.0,
          matchBadge: 'Jadwal Bentrok',
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartAssignmentSheet(
            order: order,
            recommendationsLoader: () async => recommendations,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penugasan Petugas Cerdas'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Pilihan Pelanggan'), findsOneWidget);
    expect(find.text('Candra Pratama'), findsOneWidget);
    expect(find.text('Jadwal Bentrok'), findsOneWidget);
  });

  testWidgets('SmartAssignmentSheet pins customer preferred cleaner to index 0', (WidgetTester tester) async {
    final order = OrderModel(
      id: 'ord-test-02',
      serviceId: 'srv-01',
      serviceName: 'Bersih Kos',
      orderCode: 'RSK-20261008-069',
      alamatLengkap: 'Jl. Durian No. 79',
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

    // Budi Santoso has higher score, but Siti Aminah is preferred
    final recommendations = [
      CleanerRecommendation(
        cleaner: CleanerModel(
          id: 'cln-budi',
          nama: 'Budi Santoso',
          ratingRataRata: 4.9,
          totalUlasan: 45,
          totalPekerjaan: 50,
          pengalamanTahun: 3,
          tingkatKepuasan: 98,
          ketepatanWaktu: 100,
          statusOperasional: 'Aktif',
          keahlian: ['kos'],
          sertifikasi: [],
          ulasan: [],
        ),
        score: CleanerScoreModel(
          skillScore: 40,
          availScore: 30,
          ratingScore: 20,
          effectiveRating: 4.9,
          isProvisionalRating: false,
          expScore: 10,
          totalScore: 94.0,
          matchBadge: 'Sangat Cocok',
        ),
      ),
      CleanerRecommendation(
        cleaner: CleanerModel(
          id: 'cln-siti',
          nama: 'Siti Aminah',
          ratingRataRata: 4.8,
          totalUlasan: 20,
          totalPekerjaan: 25,
          pengalamanTahun: 5,
          tingkatKepuasan: 98,
          ketepatanWaktu: 95,
          statusOperasional: 'Aktif',
          keahlian: ['kos'],
          sertifikasi: [],
          ulasan: [],
        ),
        score: CleanerScoreModel(
          skillScore: 40,
          availScore: 20,
          ratingScore: 20,
          effectiveRating: 4.8,
          isProvisionalRating: false,
          expScore: 10,
          totalScore: 86.0,
          matchBadge: 'Cocok',
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartAssignmentSheet(
            order: order,
            recommendationsLoader: () async => recommendations,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tugaskan Pilihan Pelanggan'), findsOneWidget);
    expect(find.text('Siti Aminah'), findsOneWidget);
  });
}
