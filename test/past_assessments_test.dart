import 'package:capstone/screens/assessment_history_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Past Assessments (CASE-055, CASE-056).
///
/// The list itself needs saved assessments from Supabase, so these tests only
/// prove the screen opens and handles "cannot load" safely. Check the real
/// list and tapping an entry manually on the device.
void main() {
  prepareFonts();

  testWidgets('CASE-055 (partial): screen opens with its title', (
    tester,
  ) async {
    await openScreen(tester, const AssessmentHistoryScreen());
    await tester.pumpAndSettle();

    expect(find.text('My Assessments'), findsOneWidget);
  });

  testWidgets('Load failure shows a message and a Try again button', (
    tester,
  ) async {
    await openScreen(tester, const AssessmentHistoryScreen());
    await tester.pumpAndSettle();

    expect(find.text('Could not load your assessments.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}