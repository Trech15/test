import 'package:capstone/screens/history_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Session History (CASE-059).
/// CASE-057 and CASE-058 need saved sessions from Supabase, so they cannot be
/// checked here without a fake backend. Test them manually on the device.
void main() {
  prepareFonts();

  testWidgets('CASE-059: no sessions shows the empty-state message', (
    tester,
  ) async {
    await openScreen(tester, const HistoryScreen());
    await tester.pumpAndSettle();

    expect(find.text('Session History'), findsOneWidget);
    expect(find.text('No history yet'), findsOneWidget);
    expect(
      find.text('Your past stress check-ins will appear here'),
      findsOneWidget,
    );
  });
}