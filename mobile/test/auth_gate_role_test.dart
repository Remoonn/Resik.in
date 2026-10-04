import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/main.dart';
import 'package:resik_in_mobile/models/user_model.dart';
import 'package:resik_in_mobile/screens/admin_dashboard_screen.dart';
import 'package:resik_in_mobile/screens/cleaner_dashboard_screen.dart';
import 'package:resik_in_mobile/services/auth_service.dart';

void main() {
  testWidgets('AuthGate routes to AdminDashboardScreen when user.role == admin', (WidgetTester tester) async {
    const admin = UserModel(
      id: 'usr-admin-01',
      nama: 'Admin Resik',
      email: 'admin@resik.in',
      role: 'admin',
    );
    AuthService.currentUserNotifier.value = admin;

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pump();

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
  });

  testWidgets('AuthGate routes to CleanerDashboardScreen when user.role == cleaner', (WidgetTester tester) async {
    const cleaner = UserModel(
      id: 'usr-cleaner-01',
      nama: 'Cecep',
      email: 'cecep@resik.in',
      role: 'cleaner',
      cleanerId: 'cln-01',
    );
    AuthService.currentUserNotifier.value = cleaner;

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pump();

    expect(find.byType(CleanerDashboardScreen), findsOneWidget);
  });

  testWidgets('AuthGate routes to HomeScreen when user.role == customer', (WidgetTester tester) async {
    const customer = UserModel(
      id: 'usr-customer-01',
      nama: 'Budi Santoso',
      email: 'budi@gmail.com',
      role: 'customer',
    );
    AuthService.currentUserNotifier.value = customer;

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
