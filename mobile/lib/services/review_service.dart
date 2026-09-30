import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/review_model.dart';

/// Layanan HTTP untuk komunikasi dengan backend REST API ulasan pelanggan (FR-11)
class ReviewService {
  final http.Client client;

  ReviewService({http.Client? client}) : client = client ?? http.Client();

  /// Mengirim ulasan baru untuk pesanan yang telah berstatus Selesai (FR-11)
  Future<ReviewModel?> submitReview({
    required String orderId,
    required int rating,
    String? catatanUlasan,
    String? userId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/reviews');
      final body = {
        'order_id': orderId,
        'rating': rating,
        if (catatanUlasan != null && catatanUlasan.isNotEmpty) 'catatan_ulasan': catatanUlasan,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
      };

      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return ReviewModel.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ReviewService] Error saat submitReview: $e');
      return null;
    }
  }

  /// Mengecek apakah pesanan telah memiliki ulasan tersimpan
  Future<ReviewModel?> getReviewByOrderId(String orderId) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/reviews/order/$orderId');
      final response = await client.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return ReviewModel.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ReviewService] Error saat getReviewByOrderId: $e');
      return null;
    }
  }

  /// Mengambil daftar ulasan publik untuk profil petugas
  Future<List<ReviewModel>> getCleanerReviews(String cleanerId) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/reviews/cleaner/$cleanerId');
      final response = await client.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'] as Map<String, dynamic>;
          final reviewsRaw = data['reviews'] as List<dynamic>? ?? [];
          return reviewsRaw
              .map((r) => ReviewModel.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ReviewService] Error saat getCleanerReviews: $e');
      return [];
    }
  }
}
