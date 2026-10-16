import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/screens/midtrans_snap_screen.dart';

void main() {
  testWidgets('MidtransSnapScreen menampilkan AppBar dengan kode pesanan dan tombol tutup', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: MidtransSnapScreen(
          redirectUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/mock-token',
          orderCode: 'RSK-20261025-001',
        ),
      ),
    );

    expect(find.text('Pembayaran #RSK-20261025-001'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is PopScope), findsOneWidget);
  });
}
