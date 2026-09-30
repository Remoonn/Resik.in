import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/review_model.dart';
import 'package:resik_in_mobile/screens/cleaner_detail_screen.dart';

void main() {
  group('CleanerDetailScreen Review Integration Tests', () {
    final activeCleanerWithReviews = CleanerModel(
      id: 'cln-100',
      nama: 'Budi Santoso',
      keahlian: ['rumah', 'kos'],
      pengalamanTahun: 3,
      ratingRataRata: 4.8,
      totalUlasan: 12,
      totalPekerjaan: 20,
      tingkatKepuasan: 98,
      ketepatanWaktu: 95,
      statusOperasional: 'Aktif',
      sertifikasi: const ['Sertifikasi Kebersihan'],
      ulasan: const [],
    );

    final mockVerifiedReviews = [
      ReviewModel(
        id: 'rev-bud-01',
        orderId: 'ord-bud-01',
        customerId: 'usr-001',
        customerName: 'Siti M.',
        cleanerId: 'cln-100',
        rating: 5,
        catatanUlasan: 'Sangat bersih dan datang tepat waktu!',
        createdAt: DateTime.parse('2026-09-29T10:00:00Z'),
      ),
      ReviewModel(
        id: 'rev-bud-02',
        orderId: 'ord-bud-02',
        customerId: 'usr-002',
        customerName: 'Bambang W.',
        cleanerId: 'cln-100',
        rating: 4,
        catatanUlasan: 'Pekerjaan rapi dan teliti.',
        createdAt: DateTime.parse('2026-09-28T14:30:00Z'),
      ),
    ];

    testWidgets('1. Menyembunyikan banner provisional ketika cleaner memiliki total ulasan > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CleanerDetailScreen(
            cleaner: activeCleanerWithReviews,
            initialReviews: mockVerifiedReviews,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Petugas Baru (Rating Awal 4.5)'), findsNothing);
    });

    testWidgets('2. Menampilkan daftar ulasan pelanggan terverifikasi dengan nama, bintang, dan ulasan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CleanerDetailScreen(
            cleaner: activeCleanerWithReviews,
            initialReviews: mockVerifiedReviews,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan nama reviewer dan ulasan tampil
      expect(find.text('Siti M.'), findsOneWidget);
      expect(find.text('Sangat bersih dan datang tepat waktu!'), findsOneWidget);
      expect(find.text('Bambang W.'), findsOneWidget);
      expect(find.text('Pekerjaan rapi dan teliti.'), findsOneWidget);
      expect(find.textContaining('Ulasan Pelanggan'), findsOneWidget);
    });
  });
}
