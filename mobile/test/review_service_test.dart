import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resik_in_mobile/services/review_service.dart';

void main() {
  group('ReviewService Tests', () {
    test('submitReview sukses mengembalikan ReviewModel saat HTTP 201', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/reviews');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['order_id'], 'ord-100');
        expect(body['rating'], 5);

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Rating dan ulasan berhasil dikirim',
            'data': {
              'id': 'rev-mock-01',
              'order_id': 'ord-100',
              'customer_id': 'usr-cust-01',
              'cleaner_id': 'cln-01',
              'rating': 5,
              'catatan_ulasan': 'Bagus sekali',
              'created_at': '2026-09-30T10:00:00Z',
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReviewService(client: mockClient);
      final result = await service.submitReview(
        orderId: 'ord-100',
        rating: 5,
        catatanUlasan: 'Bagus sekali',
        userId: 'usr-cust-01',
      );

      expect(result, isNotNull);
      expect(result!.id, 'rev-mock-01');
      expect(result.rating, 5);
      expect(result.catatanUlasan, 'Bagus sekali');
    });

    test('getReviewByOrderId mengembalikan ReviewModel saat ditemukan', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/reviews/order/ord-100');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'rev-mock-01',
              'order_id': 'ord-100',
              'customer_id': 'usr-cust-01',
              'cleaner_id': 'cln-01',
              'rating': 5,
              'catatan_ulasan': 'Bagus sekali',
              'created_at': '2026-09-30T10:00:00Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReviewService(client: mockClient);
      final result = await service.getReviewByOrderId('ord-100');

      expect(result, isNotNull);
      expect(result!.orderId, 'ord-100');
      expect(result.rating, 5);
    });

    test('getReviewByOrderId mengembalikan null saat HTTP 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Pesanan belum memiliki ulasan',
            'error': 'REVIEW_NOT_FOUND'
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReviewService(client: mockClient);
      final result = await service.getReviewByOrderId('ord-unreviewed');

      expect(result, isNull);
    });

    test('getCleanerReviews mengembalikan daftar ulasan saat HTTP 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/reviews/cleaner/cln-01');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'cleaner_id': 'cln-01',
              'rating_rata_rata': 4.9,
              'total_ulasan': 2,
              'reviews': [
                {
                  'id': 'rev-01',
                  'order_id': 'ord-01',
                  'customer_name': 'Ahmad F.',
                  'cleaner_id': 'cln-01',
                  'rating': 5,
                  'catatan_ulasan': 'Bersih sekali',
                  'created_at': '2026-09-30T10:00:00Z',
                },
                {
                  'id': 'rev-02',
                  'order_id': 'ord-02',
                  'customer_name': 'Budi S.',
                  'cleaner_id': 'cln-01',
                  'rating': 4,
                  'catatan_ulasan': 'Cukup rapi',
                  'created_at': '2026-09-29T10:00:00Z',
                }
              ]
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReviewService(client: mockClient);
      final list = await service.getCleanerReviews('cln-01');

      expect(list.length, 2);
      expect(list[0].customerName, 'Ahmad F.');
      expect(list[1].rating, 4);
    });
  });
}
