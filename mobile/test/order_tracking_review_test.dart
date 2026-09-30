import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/models/review_model.dart';
import 'package:resik_in_mobile/screens/order_tracking_screen.dart';

void main() {
  group('OrderTrackingScreen Review Integration Tests', () {
    final mockCompletedOrder = OrderModel(
      id: 'ord-test-rev-int-01',
      orderCode: 'RSK-20260930-999',
      serviceId: 'srv-001',
      serviceName: 'Pembersihan Kos',
      serviceCategory: 'kos',
      tanggalLayanan: '2026-09-30',
      startTime: '09:00',
      endTime: '11:00',
      duration: 2,
      alamatLengkap: 'Jl. Kaliurang KM 14.5 No. 20',
      patokanLokasi: 'Depan Warung',
      luasArea: 'Kamar 3x4',
      hargaSaatBooking: 75000.0,
      totalBiaya: 75000.0,
      statusPembayaran: 'Sudah Bayar',
      statusPekerjaan: 'Selesai',
      cleanerId: 'cleaner-01',
      cleaner: CleanerModel(
        id: 'cleaner-01',
        nama: 'Ahmad Santoso',
        nomorKontak: '081234567890',
        keahlian: ['kos'],
        pengalamanTahun: 3,
        ratingRataRata: 4.9,
        totalUlasan: 45,
        totalPekerjaan: 56,
        tingkatKepuasan: 98,
        ketepatanWaktu: 96,
        statusOperasional: 'Aktif',
        sertifikasi: const [],
        ulasan: const [],
      ),
    );

    testWidgets('Menampilkan tombol Beri Rating & Ulasan saat pesanan Selesai dan belum diulas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: mockCompletedOrder.id,
            initialOrder: mockCompletedOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Beri Rating & Ulasan Petugas'), findsOneWidget);
    });

    testWidgets('Menampilkan kartu ringkasan ulasan saat pesanan Selesai dan telah memiliki ulasan', (tester) async {
      final mockReview = ReviewModel(
        id: 'rev-test-01',
        orderId: mockCompletedOrder.id,
        customerId: 'usr-cust-001',
        cleanerId: 'cleaner-01',
        rating: 5,
        catatanUlasan: 'Pekerjaan sangat bersih dan rapi!',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: mockCompletedOrder.id,
            initialOrder: mockCompletedOrder,
            initialReview: mockReview,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ulasan Anda (5/5)'), findsOneWidget);
      expect(find.text('"Pekerjaan sangat bersih dan rapi!"'), findsOneWidget);
      expect(find.text('Terkirim'), findsOneWidget);
    });
  });
}
