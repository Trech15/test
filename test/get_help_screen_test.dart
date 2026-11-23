import 'package:capstone/models/stress_data.dart';
import 'package:capstone/screens/help_options_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Get Help (CASE-060 to CASE-064).
///
/// Not testable here:
///  - CASE-061 / 062: the phone dialer and email app open through
///    url_launcher. Check them on a real device.
///  - CASE-063 / 064 success: sending calls the Supabase function
///    "notify-guidance". Without Supabase the request fails, so these tests
///    check the failure path. Check the "Request sent" card manually.
void main() {
  prepareFonts();

  testWidgets('Help options screen shows the Talk to Guidance option', (
    tester,
  ) async {
    await openScreen(tester, const HelpOptionsScreen());

    expect(find.text('Get Help'), findsOneWidget);
    expect(find.text('How would you like to get help?'), findsOneWidget);
    expect(find.text('Talk to Guidance'), findsOneWidget);
  });

  testWidgets('High stress result shows the guidance warning', (tester) async {
    final high = StressData.fromScore(75, DateTime(2026, 11, 22));
    await openScreen(tester, HelpOptionsScreen(stressData: high));

    expect(find.textContaining('high stress'), findsOneWidget);
  });

  testWidgets('Low stress result does not show the warning', (tester) async {
    final low = StressData.fromScore(20, DateTime(2026, 11, 22));
    await openScreen(tester, HelpOptionsScreen(stressData: low));

    expect(find.textContaining('high stress'), findsNothing);
  });

  testWidgets('CASE-060: tapping Talk to Guidance opens the guidance screen', (
    tester,
  ) async {
    await openScreen(tester, const HelpOptionsScreen());

    await tester.tap(find.text('Talk to Guidance'));
    await tester.pumpAndSettle();

    expect(find.text('ADD A MESSAGE (OPTIONAL)'), findsOneWidget);
    expect(find.text('Send request to guidance'), findsOneWidget);
  });

  testWidgets(
    'CASE-063 (failure path): request with a message is attempted, and a '
    'failure is reported',
    (tester) async {
      await openScreen(tester, const HelpOptionsScreen());
      await tester.tap(find.text('Talk to Guidance'));
      await tester.pumpAndSettle();

      await typeInto(
        tester,
        'Tell them briefly what is going on...',
        'I feel very stressed about exams.',
      );
      await tapButton(tester, 'Send request to guidance');
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('We could not notify guidance right now'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CASE-064 (failure path): blank message is not blocked by validation',
    (tester) async {
      await openScreen(tester, const HelpOptionsScreen());
      await tester.tap(find.text('Talk to Guidance'));
      await tester.pumpAndSettle();

      await tapButton(tester, 'Send request to guidance');
      await tester.pump(const Duration(milliseconds: 300));

      // The request was attempted (no "message required" error). It only
      // fails here because there is no backend in the test.
      expect(
        find.textContaining('We could not notify guidance right now'),
        findsOneWidget,
      );
    },
  );
}