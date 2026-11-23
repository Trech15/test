import 'package:capstone/screens/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Authentication module, Log in (the cases that need no backend).
void main() {
  prepareFonts();

  testWidgets('CASE-002: user leaves email empty', (tester) async {
    await openScreen(tester, const LoginScreen());

    await tapButton(tester, 'Log In');

    expect(find.text('Please enter your email'), findsOneWidget);
  });

  testWidgets('CASE-003: user leaves password empty', (tester) async {
    await openScreen(tester, const LoginScreen());

    await typeInto(tester, 'Email', 'student@gmail.com');
    await tapButton(tester, 'Log In');

    expect(find.text('Please enter your password'), findsOneWidget);
    expect(find.text('Please enter your email'), findsNothing);
  });
}
