import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/user_model.dart';

void main() {
  group('UserModel Test Suite', () {
    test('1. Parse UserModel dari JSON response login backend', () {
      final json = {
        'id': 'usr-customer-001',
        'nama': 'Budi Santoso',
        'email': 'pelanggan@resik.in',
        'nomor_wa': '081234567890',
        'role': 'customer',
        'token': 'resik-token-123'
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'usr-customer-001');
      expect(user.nama, 'Budi Santoso');
      expect(user.email, 'pelanggan@resik.in');
      expect(user.role, 'customer');
      expect(user.isCustomer, true);
      expect(user.isCleaner, false);
      expect(user.isAdmin, false);
      expect(user.roleLabel, 'Pelanggan');
    });

    test('2. Parse UserModel dengan role cleaner dan cleaner_id', () {
      final json = {
        'id': 'usr-cleaner-001',
        'nama': 'Candra Pratama',
        'email': 'petugas@resik.in',
        'nomor_wa': '081234567801',
        'role': 'cleaner',
        'cleaner_id': 'cln-001'
      };

      final user = UserModel.fromJson(json);

      expect(user.isCleaner, true);
      expect(user.cleanerId, 'cln-001');
      expect(user.roleLabel, 'Petugas Kebersihan');
    });

    test('3. Parse UserModel dengan role admin', () {
      final json = {
        'id': 'usr-admin-001',
        'nama': 'Admin Resik',
        'email': 'admin@resik.in',
        'role': 'admin'
      };

      final user = UserModel.fromJson(json);

      expect(user.isAdmin, true);
      expect(user.roleLabel, 'Administrator');
    });
  });
}
