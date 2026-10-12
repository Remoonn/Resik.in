import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/main.dart';

void main() {
  testWidgets('HomeScreen memiliki tombol floating action AI untuk membuka konsultasi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();

    final fab = find.byKey(const Key('fab_tanya_resik_ai'));
    expect(fab, findsOneWidget);

    final banner = find.text('TANYA RESIK AI');
    expect(banner, findsOneWidget);
  });
}
