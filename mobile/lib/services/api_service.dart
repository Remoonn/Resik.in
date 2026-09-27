import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/service_model.dart';
import '../models/order_model.dart';
import '../models/cleaner_model.dart';

class ApiService {
  static final http.Client _client = http.Client();

  /// Mengambil daftar katalog layanan kebersihan dari backend REST API
  static Future<List<ServiceModel>> asyncFetchServices() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/services');
      final response = await _client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final List list = body['data'];
          return list.map((item) => ServiceModel.fromJson(item)).toList();
        }
      }
      return <ServiceModel>[];
    } catch (e) {
      return <ServiceModel>[];
    }
  }

  /// Membuat pesanan baru (POST /api/orders)
  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/orders');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body = jsonDecode(response.body);
      return body;
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke server backend: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Simulasi Pembayaran Server-Authoritative (POST /api/orders/:id/pay)
  static Future<Map<String, dynamic>> payOrder(String orderId) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/pay');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body = jsonDecode(response.body);
      return body;
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal melakukan pembayaran: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Mengambil detail pesanan (GET /api/orders/:id)
  static Future<OrderModel?> fetchOrderById(String orderId) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/orders/$orderId');
      final response = await _client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return OrderModel.fromJson(body['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mengambil daftar seluruh petugas aktif (GET /api/cleaners)
  static Future<List<CleanerModel>> fetchCleaners() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/cleaners');
      final response = await _client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final List list = body['data'];
          return list.map((item) => CleanerModel.fromJson(item)).toList();
        }
      }
      return <CleanerModel>[];
    } catch (e) {
      return <CleanerModel>[];
    }
  }

  /// Mengambil detail profil petugas beserta ulasan (GET /api/cleaners/:id)
  static Future<CleanerModel?> fetchCleanerById(String cleanerId) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/cleaners/$cleanerId');
      final response = await _client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return CleanerModel.fromJson(body['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mengambil rekomendasi petugas deterministik (GET /api/cleaners/recommendations)
  static Future<List<CleanerRecommendation>> fetchRecommendations({
    required String serviceId,
    required String tanggal,
    required String startTime,
    required int duration,
  }) async {
    try {
      final queryParams = {
        'service_id': serviceId,
        'tanggal': tanggal,
        'start_time': startTime,
        'duration': duration.toString(),
      };
      final uri = Uri.parse('${ApiConstants.baseUrl}/cleaners/recommendations')
          .replace(queryParameters: queryParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final List list = body['data'];
          return list.map((item) => CleanerRecommendation.fromJson(item)).toList();
        }
      }
      return <CleanerRecommendation>[];
    } catch (e) {
      return <CleanerRecommendation>[];
    }
  }
}

