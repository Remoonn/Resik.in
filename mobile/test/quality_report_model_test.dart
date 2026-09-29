import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/quality_report_model.dart';

void main() {
  group('QualityReportModel Test Suite', () {
    test('QualityReportModel parsing dari JSON harus valid dan konsisten', () {
      final json = {
        'id': 'rep-001',
        'order_id': 'ord-001',
        'cleaner_nama': 'Candra Pratama',
        'checklist_area': [
          {'area': 'Ruang Tamu', 'completed': true},
          {'area': 'Kamar Mandi', 'completed': true}
        ],
        'catatan_petugas': 'Pembersihan tuntas sesuai standar.',
        'foto_before_signed_url': 'https://supabase.mock.resik.in/before.webp',
        'foto_after_signed_url': 'https://supabase.mock.resik.in/after.webp',
        'signed_url_expires_in': 1800,
        'started_at': '2026-09-29T08:00:00.000Z',
        'completed_at': '2026-09-29T10:00:00.000Z',
        'submitted_at': '2026-09-29T10:02:00.000Z',
        'is_locked': true,
      };

      final report = QualityReportModel.fromJson(json);

      expect(report.id, 'rep-001');
      expect(report.orderId, 'ord-001');
      expect(report.cleanerNama, 'Candra Pratama');
      expect(report.checklistArea.length, 2);
      expect(report.checklistArea[0].area, 'Ruang Tamu');
      expect(report.checklistArea[0].completed, true);
      expect(report.checklistArea[1].area, 'Kamar Mandi');
      expect(report.checklistArea[1].completed, true);
      expect(report.catatanPetugas, 'Pembersihan tuntas sesuai standar.');
      expect(report.fotoBeforeSignedUrl, 'https://supabase.mock.resik.in/before.webp');
      expect(report.fotoAfterSignedUrl, 'https://supabase.mock.resik.in/after.webp');
      expect(report.signedUrlExpiresIn, 1800);
      expect(report.isLocked, true);

      // Verifikasi konversi balik toJson
      final exportedJson = report.toJson();
      expect(exportedJson['id'], 'rep-001');
      expect(exportedJson['order_id'], 'ord-001');
      expect((exportedJson['checklist_area'] as List).length, 2);
    });
  });
}
