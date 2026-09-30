import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/widgets/review_bottom_sheet.dart';

void main() {
  testWidgets('ReviewBottomSheet menampilkan bintang interaktif dan tombol teraktivasi saat rating dipilih', (tester) async {
    int? selectedRating;
    String? submittedNotes;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewBottomSheet(
            orderId: 'ord-123',
            cleanerName: 'Budi Santoso',
            serviceName: 'Pembersihan Kos',
            onSubmit: (rating, notes) async {
              selectedRating = rating;
              submittedNotes = notes;
              return true;
            },
          ),
        ),
      ),
    );

    // Verifikasi header
    expect(find.text('Beri Ulasan Petugas'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Pembersihan Kos'), findsOneWidget);

    // Tombol kirim ulasan awalnya disabled
    final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Kirim Ulasan');
    expect(submitButtonFinder, findsOneWidget);
    ElevatedButton btn = tester.widget(submitButtonFinder);
    expect(btn.onPressed, isNull);

    // Tekan bintang ke-5
    final starIcons = find.byIcon(Icons.star_rounded);
    expect(starIcons, findsNWidgets(5));
    await tester.tap(starIcons.at(4));
    await tester.pumpAndSettle();

    // Verifikasi label emosional muncul
    expect(find.text('Sangat Puas & Bersih'), findsOneWidget);

    // Tombol kirim sekarang aktif
    btn = tester.widget(submitButtonFinder);
    expect(btn.onPressed, isNotNull);

    // Ketik catatan ulasan
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'Pelayanan luar biasa, bersih sekali!');
    await tester.pumpAndSettle();

    // Tekan submit
    await tester.tap(submitButtonFinder);
    await tester.pumpAndSettle();

    expect(selectedRating, 5);
    expect(submittedNotes, 'Pelayanan luar biasa, bersih sekali!');
  });
}
