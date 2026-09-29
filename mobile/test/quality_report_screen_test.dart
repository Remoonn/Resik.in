import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/models/quality_report_model.dart';
import 'package:resik_in_mobile/screens/quality_report_screen.dart';

void main() {
  group('QualityReportScreen Widget Tests', () {
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
      statusPekerjaan: 'Selesai',
      createdAt: '2026-09-29T08:00:00.000Z',
    );

    final testReport = QualityReportModel(
      id: 'rep-001',
      orderId: 'ord-test-101',
      cleanerId: 'cln-001',
      cleanerNama: 'Candra Pratama',
      checklistArea: const [
        ChecklistItemModel(area: 'Ruang Tamu', completed: true),
        ChecklistItemModel(area: 'Kamar Tidur', completed: true),
        ChecklistItemModel(area: 'Dapur', completed: true),
        ChecklistItemModel(area: 'Kamar Mandi', completed: true),
        ChecklistItemModel(area: 'Area Tambahan Sesuai Paket', completed: true),
      ],
      catatanPetugas: 'Pembersihan tuntas sesuai standar kebersihan Resik.in.',
      fotoBeforeSignedUrl: 'https://example.com/before.webp',
      fotoAfterSignedUrl: 'https://example.com/after.webp',
      startedAt: DateTime.parse('2026-09-29T08:00:00.000Z'),
      completedAt: DateTime.parse('2026-09-29T10:00:00.000Z'),
      submittedAt: DateTime.parse('2026-09-29T10:02:15.000Z'),
      isLocked: true,
    );

    testWidgets('Menampilkan badge lock, foto komparasi, checklist terverifikasi, dan timestamp audit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityReportScreen(
            order: testOrder,
            initialReport: testReport,
          ),
        ),
      );

      // Verify header & badge
      expect(find.text('Laporan Hasil Kerja'), findsOneWidget);
      expect(find.textContaining('Laporan Mutu Terverifikasi'), findsOneWidget);

      // Verify cleaner & notes
      expect(find.textContaining('Candra Pratama'), findsOneWidget);
      expect(find.text('Pembersihan tuntas sesuai standar kebersihan Resik.in.'), findsOneWidget);

      // Verify checklist items
      expect(find.text('Ruang Tamu'), findsOneWidget);
      expect(find.text('Kamar Tidur'), findsOneWidget);
      expect(find.text('Dapur'), findsOneWidget);
      expect(find.text('Kamar Mandi'), findsOneWidget);
      expect(find.text('Area Tambahan Sesuai Paket'), findsOneWidget);

      // Verify visual comparison toggle or labels
      expect(find.text('Sebelum'), findsWidgets);
      expect(find.text('Sesudah'), findsWidgets);

      // Verify timestamps
      expect(find.textContaining('Waktu Mulai'), findsOneWidget);
      expect(find.textContaining('Waktu Selesai'), findsOneWidget);
      expect(find.textContaining('Diverifikasi Server'), findsOneWidget);
    });
  });
}
