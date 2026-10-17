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

  testWidgets('MidtransSnapScreen menampilkan UI Simulator saat token bernilai mock-snap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: MidtransSnapScreen(
          redirectUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/mock-snap-ord-123-179224',
          orderCode: 'RSK-20261025-001',
          paymentMethod: 'qris',
          totalBiaya: 120000,
        ),
      ),
    );

    expect(find.text('Simulator Pembayaran Midtrans'), findsOneWidget);
    expect(find.text('Simulasikan Pembayaran Berhasil'), findsOneWidget);
    expect(find.text('Batalkan Transaksi'), findsOneWidget);
  });
}
