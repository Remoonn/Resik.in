import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/review_model.dart';

void main() {
  group('ReviewModel Tests', () {
    test('Deserialisasi JSON valid ke ReviewModel', () {
      final json = {
        'id': 'rev-001',
        'order_id': 'ord-001',
        'customer_id': 'usr-001',
        'customer_name': 'Ahmad F.',
        'cleaner_id': 'cln-001',
        'rating': 5,
        'catatan_ulasan': 'Pekerjaan rapi sekali',
        'created_at': '2026-09-30T10:00:00.000Z',
      };

      final model = ReviewModel.fromJson(json);

      expect(model.id, 'rev-001');
      expect(model.orderId, 'ord-001');
      expect(model.customerId, 'usr-001');
      expect(model.customerName, 'Ahmad F.');
      expect(model.cleanerId, 'cln-001');
      expect(model.rating, 5);
      expect(model.catatanUlasan, 'Pekerjaan rapi sekali');
      expect(model.createdAt, isNotNull);
    });

    test('Serialisasi ReviewModel ke JSON', () {
      final model = ReviewModel(
        id: 'rev-002',
        orderId: 'ord-002',
        customerId: 'usr-002',
        cleanerId: 'cln-002',
        rating: 4,
        catatanUlasan: 'Cukup bagus',
        customerName: 'Budi S.',
        createdAt: DateTime.parse('2026-09-30T10:00:00.000Z'),
      );

      final json = model.toJson();
      expect(json['id'], 'rev-002');
      expect(json['order_id'], 'ord-002');
      expect(json['customer_id'], 'usr-002');
      expect(json['cleaner_id'], 'cln-002');
      expect(json['rating'], 4);
      expect(json['catatan_ulasan'], 'Cukup bagus');
      expect(json['customer_name'], 'Budi S.');
    });
  });
}
