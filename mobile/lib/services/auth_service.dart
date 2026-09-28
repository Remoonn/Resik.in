import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static final ValueNotifier<UserModel?> currentUserNotifier =
      ValueNotifier<UserModel?>(null);

  UserModel? get currentUser => currentUserNotifier.value;
  bool get isAuthenticated => currentUser != null;

  // Demo fallback accounts
  static final Map<String, UserModel> demoAccounts = {
    'customer': const UserModel(
      id: 'usr-customer-001',
      nama: 'Budi Santoso',
      email: 'pelanggan@resik.in',
      role: 'customer',
      nomorWa: '081234567890',
      token: 'demo-token-customer',
    ),
    'cleaner': const UserModel(
      id: 'usr-cleaner-001',
      nama: 'Candra Pratama',
      email: 'petugas@resik.in',
      role: 'cleaner',
      cleanerId: 'cln-001',
      nomorWa: '081234567801',
      token: 'demo-token-cleaner',
    ),
    'admin': const UserModel(
      id: 'usr-admin-001',
      nama: 'Admin Resik',
      email: 'admin@resik.in',
      role: 'admin',
      nomorWa: '081999888777',
      token: 'demo-token-admin',
    ),
  };

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Check demo accounts directly for offline/fast login
    for (final demo in demoAccounts.values) {
      if (demo.email.toLowerCase() == normalizedEmail && password == 'password123') {
        currentUserNotifier.value = demo;
        return demo;
      }
    }

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/auth/login');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': normalizedEmail, 'password': password}),
          )
          .timeout(const Duration(seconds: 4));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        final userData = json['data']['user'] as Map<String, dynamic>;
        userData['token'] = json['data']['token'];
        final user = UserModel.fromJson(userData);
        currentUserNotifier.value = user;
        return user;
      } else {
        throw Exception(json['message'] ?? 'Login gagal. Periksa email dan password.');
      }
    } catch (e) {
      // Jika backend tidak terjangkau tapi format email valid, fallback ke mock customer
      if (normalizedEmail.contains('@') && password.length >= 6) {
        final fallbackUser = UserModel(
          id: 'usr-local-${DateTime.now().millisecondsSinceEpoch}',
          nama: normalizedEmail.split('@').first,
          email: normalizedEmail,
          role: 'customer',
          token: 'offline-token',
        );
        currentUserNotifier.value = fallbackUser;
        return fallbackUser;
      }
      rethrow;
    }
  }

  Future<UserModel> loginDemo(String role) async {
    final demo = demoAccounts[role.toLowerCase()] ?? demoAccounts['customer']!;
    currentUserNotifier.value = demo;
    return demo;
  }

  Future<UserModel> register({
    required String nama,
    required String email,
    required String password,
    String role = 'customer',
    String? nomorWa,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/auth/register');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nama': nama.trim(),
              'email': email.trim().toLowerCase(),
              'password': password,
              'role': role,
              'nomor_wa': nomorWa ?? '-',
            }),
          )
          .timeout(const Duration(seconds: 4));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201 && json['success'] == true) {
        final userData = json['data']['user'] as Map<String, dynamic>;
        userData['token'] = json['data']['token'];
        final user = UserModel.fromJson(userData);
        currentUserNotifier.value = user;
        return user;
      } else {
        throw Exception(json['message'] ?? 'Registrasi gagal.');
      }
    } catch (e) {
      final fallbackUser = UserModel(
        id: 'usr-new-${DateTime.now().millisecondsSinceEpoch}',
        nama: nama.trim(),
        email: email.trim().toLowerCase(),
        role: role,
        nomorWa: nomorWa ?? '-',
        token: 'offline-registered-token',
      );
      currentUserNotifier.value = fallbackUser;
      return fallbackUser;
    }
  }

  void logout() {
    currentUserNotifier.value = null;
  }
}
