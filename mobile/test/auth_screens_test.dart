import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/main.dart';
import 'package:resik_in_mobile/models/user_model.dart';
import 'package:resik_in_mobile/screens/login_screen.dart';
import 'package:resik_in_mobile/screens/register_screen.dart';
import 'package:resik_in_mobile/screens/welcome_screen.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().logout();
  });

  group('Auth Screens Widget Tests', () {
    testWidgets('1. WelcomeScreen menampilkan logo, tagline, tombol Sign In, Create Account & Sign in with Google', (tester) async {
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
      expect(find.byKey(const Key('welcome_google_button')), findsOneWidget);
      expect(find.byKey(const Key('welcome_guest_button')), findsNothing);
    });

    testWidgets('2. LoginScreen menampilkan form login dan tombol Google tanpa demo role', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Masuk ke Akun Anda'), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('login_google_button')), findsOneWidget);

      // Pastikan demo role tidak ada
      expect(find.text('Masuk Cepat sebagai Pelanggan'), findsNothing);
      expect(find.text('Masuk Cepat sebagai Petugas (Cleaner)'), findsNothing);
      expect(find.text('Masuk Cepat sebagai Administrator'), findsNothing);

      // Masukkan akun login
      await tester.enterText(find.byKey(const Key('login_email_field')), 'pelanggan@resik.in');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(AuthService().isAuthenticated, true);
      expect(AuthService().currentUser?.email, 'pelanggan@resik.in');
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

    testWidgets('4. AuthGate menampilkan WelcomeScreen saat belum login dan HomeScreen saat sudah login', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGate(),
        ),
      );

      // Belum login -> Tampilkan WelcomeScreen
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Login -> Langsung beralih ke HomeScreen
      AuthService.currentUserNotifier.value = const UserModel(
        id: 'test-user',
        nama: 'Test User',
        email: 'test@resik.in',
        role: 'customer',
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}

