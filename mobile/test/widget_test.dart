import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/main.dart';

void main() {
  testWidgets('Resik.in App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ResikInApp());

    // Verify that our title exists.
    expect(find.text('Resik.in'), findsOneWidget);
  });
}
