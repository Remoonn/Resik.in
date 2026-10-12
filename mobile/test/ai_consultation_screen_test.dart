import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/screens/ai_consultation_screen.dart';

void main() {
  testWidgets('1. AiConsultationScreen menampilkan header Resik AI, status online, dan pesan sambutan awal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AiConsultationScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Resik AI'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.textContaining('asisten pintar'), findsOneWidget);
    expect(find.byKey(const Key('input_ai_message')), findsOneWidget);
    expect(find.byKey(const Key('btn_send_ai_message')), findsOneWidget);
  });

  testWidgets('2. Mengetik pesan dan mengirim menambahkan bubble pesan ke percakapan', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AiConsultationScreen(),
      ),
    );
    await tester.pump();

    // Input teks
    await tester.enterText(find.byKey(const Key('input_ai_message')), 'Halo, butuh saran untuk kosan');
    await tester.pump();

    // Tekan kirim
    await tester.tap(find.byKey(const Key('btn_send_ai_message')));
    await tester.pump();

    // Verifikasi pesan user muncul
    expect(find.text('Halo, butuh saran untuk kosan'), findsOneWidget);
  });
}
