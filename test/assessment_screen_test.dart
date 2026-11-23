import 'package:capstone/screens/assessment_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Assessment module.
void main() {
  prepareFonts();

  testWidgets('CASE-039: Next without answering the question', (tester) async {
    await openScreen(tester, const AssessmentScreen());

    await tapButton(tester, 'Next Question →');

    expect(find.text('Please select an answer'), findsOneWidget);
  });
}
