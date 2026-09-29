import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/quality_report_model.dart';

/// Layanan integrasi Laporan Mutu (Quality Report) dengan Backend REST API
class QualityReportService {
  static final http.Client _client = http.Client();
  static final Map<String, String> _localBeforePhotos = {};
  static final Map<String, String> _localAfterPhotos = {};

  /// Menyimpan path foto lokal per ID pesanan untuk pratinjau instan di perangkat
  static void setLocalPhotos(String orderId, {String? before, String? after}) {
    if (before != null && before.isNotEmpty) {
      _localBeforePhotos[orderId] = before;
    }
    if (after != null && after.isNotEmpty) {
      _localAfterPhotos[orderId] = after;
    }
  }

  /// Mengambil path foto lokal jika tersedia di memori perangkat
  static String? getLocalPhoto(String orderId, {required bool isBefore}) {
    return isBefore ? _localBeforePhotos[orderId] : _localAfterPhotos[orderId];
  }

  /// Mendapatkan template area checklist berdasarkan kategori layanan
  List<String> getChecklistTemplateForCategory(String? category) {
    final cat = (category ?? '').toLowerCase();
    switch (cat) {
      case 'kos':
        return [
          'Kamar Tidur / Utama',
          'Kamar Mandi',
          'Area yang Termasuk Paket',
        ];
      case 'kantor':
        return [
          'Ruang Kerja',
          'Area Umum / Koridor',
          'Toilet Kantor',
          'Pantry / Dapur Bersih',
        ];
      case 'renovasi':
      case 'pasca_renovasi':
        return [
          'Area Utama Pekerjaan',
          'Pembersihan Lantai & Sudut Ruangan',
          'Pembersihan Debu & Sisa Material Semen/Cat',
          'Ruangan yang Termasuk Paket',
        ];
      case 'rumah':
      default:
        return [
          'Ruang Tamu',
          'Kamar Tidur',
          'Dapur',
          'Kamar Mandi',
          'Area Tambahan Sesuai Paket',
        ];
    }
  }

  /// Mengirim Laporan Mutu ke backend (POST /api/quality-reports)
  Future<Map<String, dynamic>> submitReport(Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/quality-reports');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> body = jsonDecode(response.body);
      return body;
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal mengirim laporan mutu: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }

  /// Mengambil data Laporan Mutu via Signed URL (GET /api/quality-reports/:orderId)
  Future<QualityReportModel?> fetchReport(String orderId, {String? userId, String? role}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null && userId.isNotEmpty) queryParams['user_id'] = userId;
      if (role != null && role.isNotEmpty) queryParams['role'] = role;

      final uri = Uri.parse('${ApiConstants.baseUrl}/quality-reports/$orderId')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return QualityReportModel.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
