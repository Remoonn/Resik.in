import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/ai_consultation_model.dart';

void main() {
  group('AiConsultationModel Unit Tests', () {
    test('1. Deserialisasi AiConsultationResponse dengan recommended_service lengkap', () {
      final json = {
        'reply': 'Disarankan Pembersihan Kos',
        'recommended_service': {
          'id': 'srv-002-kos',
          'nama_layanan': 'Pembersihan Kos',
          'kategori': 'kos',
          'tarif_dasar': 60000,
          'durasi_estimasi': '1 - 2 Jam',
          'suggested_duration': 1,
          'rationale': 'Cocok untuk kamar 3x4 meter.'
        },
        'suggested_replies': ['Berapa tarifnya?', 'Pesan sekarang']
      };

      final response = AiConsultationResponse.fromJson(json);

      expect(response.reply, 'Disarankan Pembersihan Kos');
      expect(response.recommendedService, isNotNull);
      expect(response.recommendedService!.id, 'srv-002-kos');
      expect(response.recommendedService!.namaLayanan, 'Pembersihan Kos');
      expect(response.recommendedService!.tarifDasar, 60000.0);
      expect(response.recommendedService!.suggestedDuration, 1);
      expect(response.suggestedReplies.length, 2);
    });

    test('2. Deserialisasi AiConsultationResponse tanpa recommended_service (FAQ)', () {
      final json = {
        'reply': 'Jam operasional buka 08:00 - 17:00 WIB',
        'recommended_service': null,
        'suggested_replies': <String>[]
      };

      final response = AiConsultationResponse.fromJson(json);

      expect(response.recommendedService, isNull);
      expect(response.suggestedReplies, isEmpty);
    });
  });
}
