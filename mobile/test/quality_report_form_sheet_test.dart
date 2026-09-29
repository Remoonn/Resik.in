import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/widgets/quality_report_form_sheet.dart';

void main() {
  group('QualityReportFormSheet Widget Tests', () {
    final testOrder = OrderModel(
      id: 'ord-test-101',
      orderCode: 'RSK-20260929-101',
      serviceId: 'srv-001-rumah',
      serviceName: 'Pembersihan Rumah',
      serviceCategory: 'rumah',
      cleanerId: 'cln-001',
      tanggalLayanan: '2026-09-30',
      startTime: '09:00',
      endTime: '11:00',
      duration: 2,
      alamatLengkap: 'Jl. Kaliurang KM 14.5 No. 20',
      patokanLokasi: 'Depan Warung Biru',
      luasArea: 'Tipe 36',
      hargaSaatBooking: 120000,
      totalBiaya: 120000,
      statusPembayaran: 'Sudah Bayar',
      statusPekerjaan: 'Sedang Dikerjakan',
      createdAt: '2026-09-29T08:00:00.000Z',
    );

    testWidgets('Form sheet menampilkan 5 checklist area untuk pembersihan rumah', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QualityReportFormSheet(order: testOrder),
          ),
        ),
      );

      expect(find.text('Laporan Mutu Hasil Kerja'), findsOneWidget);
      expect(find.text('Ruang Tamu'), findsOneWidget);
      expect(find.text('Kamar Tidur'), findsOneWidget);
      expect(find.text('Dapur'), findsOneWidget);
      expect(find.text('Kamar Mandi'), findsOneWidget);
      expect(find.text('Area Tambahan Sesuai Paket'), findsOneWidget);
      expect(find.text('Foto Sebelum (Before)'), findsOneWidget);
      expect(find.text('Foto Sesudah (After)'), findsOneWidget);
      expect(find.text('Kirim Laporan Mutu & Selesaikan'), findsOneWidget);
    });

    testWidgets('Tombol kirim laporan dinonaktifkan jika foto atau checklist belum lengkap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QualityReportFormSheet(order: testOrder),
          ),
        ),
      );

      final submitBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kirim Laporan Mutu & Selesaikan'),
      );

      // Awalnya tombol disabled karena checklist belum semua tercentang dan foto belum ada
      expect(submitBtn.onPressed, isNull);
    });
  });
}
