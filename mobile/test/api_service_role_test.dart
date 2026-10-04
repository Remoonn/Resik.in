import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/user_model.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService & Role Header Tests', () {
    test('AuthService.authHeaders returns correct headers for customer, cleaner, and admin', () {
      final auth = AuthService();

      // Test Cleaner Headers
      const cleanerUser = UserModel(
        id: 'usr-cleaner-001',
        nama: 'Cecep',
        email: 'cecep@resik.in',
        role: 'cleaner',
        cleanerId: 'cln-001',
      );
      AuthService.currentUserNotifier.value = cleanerUser;
      expect(auth.authHeaders['x-user-id'], 'usr-cleaner-001');
      expect(auth.authHeaders['x-user-role'], 'cleaner');
      expect(auth.authHeaders['x-cleaner-id'], 'cln-001');

      // Test Admin Headers
      const adminUser = UserModel(
        id: 'usr-admin-001',
        nama: 'Admin Resik',
        email: 'admin@resik.in',
        role: 'admin',
      );
      AuthService.currentUserNotifier.value = adminUser;
      expect(auth.authHeaders['x-user-id'], 'usr-admin-001');
      expect(auth.authHeaders['x-user-role'], 'admin');
      expect(auth.authHeaders.containsKey('x-cleaner-id'), false);

      // Test Customer Headers
      const customerUser = UserModel(
        id: 'usr-customer-001',
        nama: 'Budi Pelanggan',
        email: 'budi@gmail.com',
        role: 'customer',
      );
      AuthService.currentUserNotifier.value = customerUser;
      expect(auth.authHeaders['x-user-id'], 'usr-customer-001');
      expect(auth.authHeaders['x-user-role'], 'customer');
      expect(auth.authHeaders.containsKey('x-cleaner-id'), false);
    });
  });
}
