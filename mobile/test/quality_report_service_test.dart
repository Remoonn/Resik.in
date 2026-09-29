import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/services/quality_report_service.dart';

void main() {
  group('QualityReportService Test Suite', () {
    final service = QualityReportService();

    test('getChecklistTemplateForCategory mengembalikan 5 area untuk rumah', () {
      final areas = service.getChecklistTemplateForCategory('rumah');
      expect(areas.length, 5);
      expect(areas.contains('Ruang Tamu'), true);
      expect(areas.contains('Kamar Tidur'), true);
      expect(areas.contains('Dapur'), true);
      expect(areas.contains('Kamar Mandi'), true);
      expect(areas.contains('Area Tambahan Sesuai Paket'), true);
    });

    test('getChecklistTemplateForCategory mengembalikan 3 area untuk kos', () {
      final areas = service.getChecklistTemplateForCategory('kos');
      expect(areas.length, 3);
      expect(areas.contains('Kamar Tidur / Utama'), true);
      expect(areas.contains('Kamar Mandi'), true);
      expect(areas.contains('Area yang Termasuk Paket'), true);
    });

    test('getChecklistTemplateForCategory mengembalikan 4 area untuk kantor', () {
      final areas = service.getChecklistTemplateForCategory('kantor');
      expect(areas.length, 4);
      expect(areas.contains('Ruang Kerja'), true);
      expect(areas.contains('Area Umum / Koridor'), true);
      expect(areas.contains('Toilet Kantor'), true);
      expect(areas.contains('Pantry / Dapur Bersih'), true);
    });

    test('getChecklistTemplateForCategory mengembalikan 4 area untuk pasca renovasi', () {
      final areas = service.getChecklistTemplateForCategory('renovasi');
      expect(areas.length, 4);
      expect(areas.contains('Area Utama Pekerjaan'), true);
      expect(areas.contains('Pembersihan Lantai & Sudut Ruangan'), true);
      expect(areas.contains('Pembersihan Debu & Sisa Material Semen/Cat'), true);
      expect(areas.contains('Ruangan yang Termasuk Paket'), true);
    });
  });
}
