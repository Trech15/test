import 'package:capstone/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Authentication module, Update Password (form checks only).
void main() {
  prepareFonts();

  Future<void> openReset(WidgetTester tester) =>
      openScreen(tester, const ResetPasswordScreen());

  bool formValid(WidgetTester tester) =>
      tester.state<FormState>(find.byType(Form)).validate();

  testWidgets('CASE-013: fewer than 6 characters', (tester) async {
    await openReset(tester);
    await typeInto(tester, 'New password', 'abc');
    await tapButton(tester, 'Update password');

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('CASE-014: 6 or more characters', (tester) async {
    await openReset(tester);
    await typeInto(tester, 'New password', '123456');
    await typeInto(tester, 'Confirm new password', '123456');

    expect(formValid(tester), isTrue);
  });

  testWidgets('CASE-015: passwords do not match', (tester) async {
    await openReset(tester);
    await typeInto(tester, 'New password', 'password1');
    await typeInto(tester, 'Confirm new password', 'password2');
    await tapButton(tester, 'Update password');

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('CASE-016: passwords match', (tester) async {
    await openReset(tester);
    await typeInto(tester, 'New password', 'password1');
    await typeInto(tester, 'Confirm new password', 'password1');

    expect(formValid(tester), isTrue);
  });
}
