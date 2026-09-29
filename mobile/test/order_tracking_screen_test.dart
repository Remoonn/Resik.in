import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/screens/order_tracking_screen.dart';

void main() {
  group('OrderTrackingScreen Widget Tests', () {
    final mockOrder = OrderModel(
      id: 'ord-test-001',
      orderCode: 'RSK-20260930-001',
      serviceId: 'srv-001',
      serviceName: 'Pembersihan Rumah Mendalam',
      tanggalLayanan: '2026-09-30',
      startTime: '09:00',
      endTime: '11:00',
      duration: 2,
      alamatLengkap: 'Jl. Kaliurang KM 14.5 No. 20, Sleman',
      patokanLokasi: 'Depan Warung Madura cat biru',
      luasArea: 'Tipe 36',
      hargaSaatBooking: 120000.0,
      totalBiaya: 120000.0,
      statusPembayaran: 'Sudah Bayar',
      statusPekerjaan: 'Menuju Lokasi',
      cleanerId: 'cleaner-01',
      cleaner: CleanerModel(
        id: 'cleaner-01',
        nama: 'Ahmad Santoso',
        nomorKontak: '081234567890',
        keahlian: ['rumah', 'kos'],
        pengalamanTahun: 3,
        ratingRataRata: 4.9,
        totalUlasan: 45,
        totalPekerjaan: 56,
        tingkatKepuasan: 98,
        ketepatanWaktu: 96,
        statusOperasional: 'Bertugas',
        sertifikasi: ['BNSP K3'],
        ulasan: [],
      ),
    );

    testWidgets('1. Menampilkan header pelacakan, nama layanan, dan status aktif', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: mockOrder.id,
            initialOrder: mockOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pelacakan Cleaner'), findsOneWidget);
      expect(find.text('Pembersihan Rumah Mendalam'), findsOneWidget);
      expect(find.text('MENUJU LOKASI'), findsOneWidget);
      expect(find.text('Ahmad Santoso'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('2. Menampilkan 7 tahapan stepper alur pengerjaan layanan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: mockOrder.id,
            initialOrder: mockOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Alur Pengerjaan Layanan'), findsOneWidget);
      expect(find.text('1. Menunggu Konfirmasi'), findsOneWidget);
      expect(find.text('2. Dikonfirmasi'), findsOneWidget);
      expect(find.text('3. Petugas Ditugaskan'), findsOneWidget);
      expect(find.text('4. Menuju Lokasi'), findsOneWidget);
      expect(find.text('5. Tiba di Lokasi'), findsOneWidget);
      expect(find.text('6. Sedang Dikerjakan'), findsOneWidget);
      expect(find.text('7. Selesai'), findsOneWidget);
    });

    testWidgets('3. Menampilkan dialog konfirmasi pembatalan ketika status mengizinkan pembatalan oleh customer', (tester) async {
      final cancellableOrder = OrderModel(
        id: 'ord-test-003',
        orderCode: 'RSK-20260930-003',
        serviceId: 'srv-001',
        serviceName: 'Pembersihan Rumah',
        tanggalLayanan: '2026-09-30',
        startTime: '14:00',
        endTime: '16:00',
        duration: 2,
        alamatLengkap: 'Jl. Kaliurang KM 10',
        patokanLokasi: 'Sebelah Apotek',
        luasArea: 'Tipe 45',
        hargaSaatBooking: 150000.0,
        totalBiaya: 150000.0,
        statusPembayaran: 'Sudah Bayar',
        statusPekerjaan: 'Dikonfirmasi',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: cancellableOrder.id,
            initialOrder: cancellableOrder,
          ),
        ),
      );
      await tester.pump();

      final cancelBtn = find.text('Batalkan Pesanan');
      expect(cancelBtn, findsOneWidget);

      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Batalkan Pesanan'), findsWidgets);
      expect(find.text('Apakah Anda yakin ingin membatalkan pesanan ini? Masukkan alasan pembatalan:'), findsOneWidget);
      expect(find.text('Ya, Batalkan'), findsOneWidget);
    });

    testWidgets('4. Menampilkan kartu timer dan progres saat status Sedang Dikerjakan', (tester) async {
      final activeOrder = OrderModel(
        id: 'ord-test-002',
        orderCode: 'RSK-20260930-002',
        serviceId: 'srv-001',
        serviceName: 'Pembersihan Kamar Kos',
        tanggalLayanan: '2026-09-30',
        startTime: '10:00',
        endTime: '12:00',
        duration: 2,
        alamatLengkap: 'Jl. Kaliurang KM 12',
        patokanLokasi: 'Gerbang Hijau',
        luasArea: 'Kos Standar',
        hargaSaatBooking: 80000.0,
        totalBiaya: 80000.0,
        statusPembayaran: 'Sudah Bayar',
        statusPekerjaan: 'Sedang Dikerjakan',
        startedAt: DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        cleanerId: 'cleaner-02',
        cleaner: CleanerModel(
          id: 'cleaner-02',
          nama: 'Budi Darmawan',
          nomorKontak: '081298765432',
          keahlian: ['kos'],
          pengalamanTahun: 2,
          ratingRataRata: 4.9,
          totalUlasan: 60,
          totalPekerjaan: 88,
          tingkatKepuasan: 99,
          ketepatanWaktu: 99,
          statusOperasional: 'Bertugas',
          sertifikasi: ['BNSP K3'],
          ulasan: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: activeOrder.id,
            initialOrder: activeOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Durasi Berjalan'), findsOneWidget);
      expect(find.text('Pembersihan mendalam sedang aktif'), findsOneWidget);
      expect(find.text('Progres Tahap'), findsOneWidget);
    });

    testWidgets('5. Menampilkan banner Laporan Mutu dan tombol navigasi saat status pesanan adalah Selesai', (tester) async {
      final completedOrder = OrderModel(
        id: 'ord-test-005',
        orderCode: 'RSK-20260930-005',
        serviceId: 'srv-001',
        serviceName: 'Pembersihan Rumah',
        serviceCategory: 'rumah',
        tanggalLayanan: '2026-09-30',
        startTime: '08:00',
        endTime: '10:00',
        duration: 2,
        alamatLengkap: 'Jl. Kaliurang KM 14.5 No. 20',
        patokanLokasi: 'Depan Warung Biru',
        luasArea: 'Tipe 36',
        hargaSaatBooking: 120000.0,
        totalBiaya: 120000.0,
        statusPembayaran: 'Sudah Bayar',
        statusPekerjaan: 'Selesai',
        cleanerId: 'cleaner-01',
        cleaner: CleanerModel(
          id: 'cleaner-01',
          nama: 'Ahmad Santoso',
          nomorKontak: '081234567890',
          keahlian: ['rumah'],
          pengalamanTahun: 3,
          ratingRataRata: 4.9,
          totalUlasan: 45,
          totalPekerjaan: 56,
          tingkatKepuasan: 98,
          ketepatanWaktu: 96,
          statusOperasional: 'Aktif',
          sertifikasi: ['BNSP K3'],
          ulasan: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: completedOrder.id,
            initialOrder: completedOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Lihat Laporan Mutu (Quality Report)'), findsOneWidget);
      expect(find.text('Laporan Hasil Pekerjaan Siap Ditinjau'), findsOneWidget);
    });

    testWidgets('6. Menampilkan checklist real-time sesuai kategori pesanan (Kos)', (tester) async {
      final kosOrder = OrderModel(
        id: 'ord-test-kos',
        orderCode: 'RSK-20260930-KOS',
        serviceId: 'srv-kos-001',
        serviceName: 'Pembersihan Kos',
        serviceCategory: 'kos',
        tanggalLayanan: '2026-09-30',
        startTime: '10:00',
        endTime: '12:00',
        duration: 2,
        alamatLengkap: 'Jl. Kaliurang KM 12',
        patokanLokasi: 'Kos Melati',
        luasArea: 'Kamar 3x4 m',
        hargaSaatBooking: 75000.0,
        totalBiaya: 75000.0,
        statusPembayaran: 'Sudah Bayar',
        statusPekerjaan: 'Sedang Dikerjakan',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: kosOrder.id,
            initialOrder: kosOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Checklist Pembersihan Real-Time'), findsOneWidget);
      expect(find.text('Kamar Tidur / Utama'), findsOneWidget);
      expect(find.text('Kamar Mandi'), findsOneWidget);
      expect(find.text('Area yang Termasuk Paket'), findsOneWidget);
      // Memastikan item renovasi tidak muncul pada kos
      expect(find.text('Pengikisan sisa semen kering di lantai'), findsNothing);
    });
  });
}
