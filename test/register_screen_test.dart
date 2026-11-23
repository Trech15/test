import 'package:capstone/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Authentication module, Register (form checks only, nothing is sent).
void main() {
  prepareFonts();

  Future<void> openRegister(WidgetTester tester) =>
      openScreen(tester, const RegisterScreen());

  Future<void> fillAccount(WidgetTester tester) async {
    await typeInto(tester, 'Full Name', 'Juan Dela Cruz');
    await typeInto(tester, 'Email Address', 'juan@gmail.com');
    await typeInto(tester, 'ID Number', '2024-0001');
    await typeInto(tester, 'Password', 'secret123');
    await typeInto(tester, 'Confirm Password', 'secret123');
  }

  Future<void> chooseRelationship(WidgetTester tester) async {
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.pump();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parent').last);
    await tester.pumpAndSettle();
  }

  Future<void> fillContact(WidgetTester tester) async {
    await typeInto(tester, 'Contact name', 'Maria Dela Cruz');
    await chooseRelationship(tester);
    await typeInto(tester, 'Mobile number, e.g. 09171234567', '09171234567');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
  }

  // The page has two forms: the account fields and the emergency contact.
  bool accountFormValid(WidgetTester tester) =>
      tester.state<FormState>(find.byType(Form).at(0)).validate();

  bool contactFormValid(WidgetTester tester) =>
      tester.state<FormState>(find.byType(Form).at(1)).validate();

  const phoneError = 'Enter a valid number, e.g. 09171234567 or +639171234567';

  testWidgets('CASE-018: user leaves everything empty', (tester) async {
    await openRegister(tester);
    await tapButton(tester, 'Register');

    expect(find.text('Please enter your full name'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your ID'), findsOneWidget);
    expect(find.text('Please enter a password'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);
  });

  testWidgets('Email without a proper address is rejected', (tester) async {
    await openRegister(tester);
    await typeInto(tester, 'Email Address', 'asdasd');
    await tapButton(tester, 'Register');

    expect(find.textContaining('valid email'), findsOneWidget);
  });

  testWidgets('CASE-019: password shorter than 6 characters', (tester) async {
    await openRegister(tester);
    await typeInto(tester, 'Password', '123');
    await tapButton(tester, 'Register');

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('CASE-020: password of 6 or more characters', (tester) async {
    await openRegister(tester);
    await fillAccount(tester);

    expect(accountFormValid(tester), isTrue);
    await tester.pump();
    expect(find.text('Password must be at least 6 characters'), findsNothing);
  });

  testWidgets('CASE-021: passwords do not match', (tester) async {
    await openRegister(tester);
    await typeInto(tester, 'Password', 'password1');
    await typeInto(tester, 'Confirm Password', 'password2');
    await tapButton(tester, 'Register');

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('CASE-022: passwords match', (tester) async {
    await openRegister(tester);
    await typeInto(tester, 'Password', 'password1');
    await typeInto(tester, 'Confirm Password', 'password1');
    await tapButton(tester, 'Register');

    expect(find.text('Passwords do not match'), findsNothing);
  });

  testWidgets('CASE-023: emergency contact name left blank', (tester) async {
    await openRegister(tester);
    await tapButton(tester, 'Register');

    expect(find.text("Please enter your contact's name"), findsOneWidget);
  });

  testWidgets('CASE-024: valid emergency contact name', (tester) async {
    await openRegister(tester);
    await typeInto(tester, 'Contact name', 'Maria Dela Cruz');
    await tapButton(tester, 'Register');

    expect(find.text("Please enter your contact's name"), findsNothing);
  });

  testWidgets('CASE-025: no relationship chosen', (tester) async {
    await openRegister(tester);
    await tapButton(tester, 'Register');

    expect(find.text('Please choose a relationship'), findsOneWidget);
  });

  testWidgets('CASE-026: a relationship is chosen', (tester) async {
    await openRegister(tester);
    await chooseRelationship(tester);
    await tapButton(tester, 'Register');

    expect(find.text('Please choose a relationship'), findsNothing);
  });

  testWidgets('CASE-027: emergency contact number left blank', (tester) async {
    await openRegister(tester);
    await tapButton(tester, 'Register');

    expect(find.text(phoneError), findsOneWidget);
  });

  testWidgets('CASE-028: valid emergency contact number', (tester) async {
    await openRegister(tester);
    await typeInto(tester, 'Mobile number, e.g. 09171234567', '09171234567');
    await tapButton(tester, 'Register');

    expect(find.text(phoneError), findsNothing);
  });

  testWidgets('Consent box must be ticked', (tester) async {
    await openRegister(tester);
    await tapButton(tester, 'Register');

    expect(find.text('You need to agree to continue'), findsOneWidget);
  });

  testWidgets('CASE-029: every field filled in correctly', (tester) async {
    await openRegister(tester);
    await fillAccount(tester);
    await fillContact(tester);

    expect(accountFormValid(tester), isTrue);
    expect(contactFormValid(tester), isTrue);
  });
}
