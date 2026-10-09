import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/service_model.dart';
import '../models/order_model.dart';
import '../models/cleaner_model.dart';
import 'auth_service.dart';

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
      final user = AuthService().currentUser;
      final url = Uri.parse('${ApiConstants.baseUrl}/orders');
      final headers = {
        'Content-Type': 'application/json',
        if (user?.id != null && user!.id.isNotEmpty) 'x-user-id': user.id,
        if (user?.role != null && user!.role.isNotEmpty) 'x-user-role': user.role,
      };
      final response = await _client.post(
        url,
        headers: headers,
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

  /// Mengambil daftar pesanan (GET /api/orders) dengan dukungan multi-role (Customer, Cleaner, Admin)
  static Future<List<OrderModel>> fetchOrders({
    String? status,
    String? customerId,
    String? cleanerId,
    String? role,
  }) async {
    try {
      final user = AuthService().currentUser;
      final effectiveRole = role ?? user?.role ?? 'customer';
      final effectiveUserId = customerId ?? ((effectiveRole == 'cleaner' || effectiveRole == 'admin') ? null : user?.id);
      final effectiveCleanerId = cleanerId ?? (effectiveRole == 'cleaner' ? user?.cleanerId : null);

      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
        queryParams['customer_id'] = effectiveUserId;
      }
      if (effectiveCleanerId != null && effectiveCleanerId.isNotEmpty) {
        queryParams['cleaner_id'] = effectiveCleanerId;
      }
      if (effectiveRole.isNotEmpty) {
        queryParams['role'] = effectiveRole;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/orders').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (user != null && user.id.isNotEmpty) 'x-user-id': user.id,
        if (effectiveRole.isNotEmpty) 'x-user-role': effectiveRole,
        if (effectiveCleanerId != null && effectiveCleanerId.isNotEmpty) 'x-cleaner-id': effectiveCleanerId,
      };

      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final List list = body['data'];
          final allOrders = list.map((item) => OrderModel.fromJson(item)).toList();

          // Client-side safety filter: isolasi pesanan pelanggan vs petugas
          if (effectiveRole == 'cleaner' && effectiveCleanerId != null && effectiveCleanerId.isNotEmpty) {
            return allOrders.where((o) => o.cleanerId == effectiveCleanerId).toList();
          } else if (effectiveRole != 'admin' && effectiveUserId != null && effectiveUserId.isNotEmpty) {
            return allOrders.where((o) => o.customerId == effectiveUserId).toList();
          }
          return allOrders;
        }
      }
      return <OrderModel>[];
    } catch (e) {
      return <OrderModel>[];
    }
  }

  /// Memperbarui status pesanan sekuensial (PATCH /api/orders/:id/status)
  static Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String statusBaru, {
    String role = 'cleaner',
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/status');
      final response = await _client.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status_baru': statusBaru,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal memperbarui status pesanan: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Menugaskan petugas ke pesanan (POST /api/orders/:id/assign)
  static Future<Map<String, dynamic>> assignCleaner(
    String orderId,
    String cleanerId, {
    String role = 'admin',
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/assign');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cleaner_id': cleanerId,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal menugaskan petugas: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Mengganti petugas pesanan (POST /api/orders/:id/reassign)
  static Future<Map<String, dynamic>> reassignCleaner(
    String orderId,
    String newCleanerId,
    String alasan, {
    String role = 'admin',
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/reassign');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'new_cleaner_id': newCleanerId,
          'alasan': alasan,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal mengalihkan petugas: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Membatalkan pesanan (POST /api/orders/:id/cancel)
  static Future<Map<String, dynamic>> cancelOrder(
    String orderId,
    String reason, {
    String role = 'customer',
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/cancel');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cancellation_reason': reason,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal membatalkan pesanan: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Memperbarui status operasional administratif petugas (PATCH /api/cleaners/:id/status)
  static Future<Map<String, dynamic>> updateCleanerStatus(
    String cleanerId,
    String statusOperasional,
  ) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/cleaners/$cleanerId/status');
      final response = await _client.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status_operasional': statusOperasional,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal memperbarui status petugas: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Mendaftarkan petugas kebersihan baru (POST /api/cleaners) — Admin Only
  static Future<Map<String, dynamic>> createCleaner({
    required String nama,
    required String nomorKontak,
    required List<String> keahlian,
    required int pengalamanTahun,
    String? fotoUrl,
    String? fotoData,
    String? email,
    String? password,
    String? tentang,
    List<String>? sertifikasi,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/cleaners');
      final body = <String, dynamic>{
        'nama': nama,
        'nomor_kontak': nomorKontak,
        'keahlian': keahlian,
        'pengalaman_tahun': pengalamanTahun,
      };
      if (fotoUrl != null) body['foto_url'] = fotoUrl;
      if (fotoData != null) body['foto_data'] = fotoData;
      if (email != null) body['email'] = email;
      if (password != null) body['password'] = password;
      if (tentang != null) body['tentang'] = tentang;
      if (sertifikasi != null) body['sertifikasi'] = sertifikasi;

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal mendaftarkan petugas: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }
}


