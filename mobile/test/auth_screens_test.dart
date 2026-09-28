import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/screens/login_screen.dart';
import 'package:resik_in_mobile/screens/register_screen.dart';
import 'package:resik_in_mobile/screens/welcome_screen.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().logout();
  });

  group('Auth Screens Widget Tests', () {
    testWidgets('1. WelcomeScreen menampilkan logo, tagline, tombol Sign In & Create Account', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      expect(find.text('Resik.in'), findsOneWidget);
      expect(find.text('Pristine On-Demand Cleaning'), findsOneWidget);
      expect(find.text('Solusi Bersih Praktis & Andal untuk Hunian Anda'), findsOneWidget);
      expect(find.byKey(const Key('welcome_signin_button')), findsOneWidget);
      expect(find.byKey(const Key('welcome_create_account_button')), findsOneWidget);
      expect(find.byKey(const Key('welcome_guest_button')), findsOneWidget);
    });

    testWidgets('2. LoginScreen menampilkan form login, validasi, dan tombol demo role', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Masuk ke Akun Anda'), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.text('Masuk Cepat sebagai Pelanggan'), findsOneWidget);
      expect(find.text('Masuk Cepat sebagai Petugas (Cleaner)'), findsOneWidget);
      expect(find.text('Masuk Cepat sebagai Administrator'), findsOneWidget);

      // Tap demo customer login
      await tester.tap(find.text('Masuk Cepat sebagai Pelanggan'));
      await tester.pumpAndSettle();

      expect(AuthService().isAuthenticated, true);
      expect(AuthService().currentUser?.role, 'customer');
    });

    testWidgets('3. RegisterScreen menampilkan form pendaftaran lengkap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );

      expect(find.widgetWithText(AppBar, 'Create Account'), findsOneWidget);
      expect(find.byKey(const Key('register_name_field')), findsOneWidget);
      expect(find.byKey(const Key('register_email_field')), findsOneWidget);
      expect(find.byKey(const Key('register_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('register_role_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('register_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_terms_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
    });
  });
}
