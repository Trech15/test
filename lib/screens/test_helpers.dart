import 'package:capstone/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Put this file in test/test_helpers.dart
/// (it has no tests of its own; the other test files use it).

/// Call once at the top of main() in every test file. It stops google_fonts
/// from trying to download fonts while the tests run.
void prepareFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// A tall screen so long forms (like Register) are fully visible.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Shows a screen inside a MaterialApp with your app theme.
Future<void> openScreen(
  WidgetTester tester,
  Widget screen, {
  Map<String, WidgetBuilder> routes = const {},
}) async {
  useTallScreen(tester);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, routes: routes, home: screen),
  );

  await tester.pump();
}

/// Finds a text box by its hint text, for example 'Full Name'.
Finder fieldWithHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}

Future<void> typeInto(WidgetTester tester, String hint, String text) async {
  await tester.enterText(fieldWithHint(hint), text);
  await tester.pump();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);

  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
