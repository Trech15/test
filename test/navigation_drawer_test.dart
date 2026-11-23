import 'package:capstone/widgets/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Navigation module: the slide-out drawer (9-dots button).
void main() {
  prepareFonts();

  Future<void> openApp(WidgetTester tester) async {
    Widget page(String label) => Scaffold(body: Center(child: Text(label)));

    await openScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: const AppMenuButton(),
            // Room for the back arrow + menu icon. While the drawer is open
            // the menu button also shows its back arrow (a route sits on top
            // of the screen), so 56 would overflow in the test.
            leadingWidth: 104,
          ),
          body: const Center(child: Text('HOME SCREEN')),
        ),
      ),
      routes: {
        '/dashboard': (_) => page('DASHBOARD SCREEN'),
        '/voice_input': (_) => page('VOICE SCREEN'),
        '/assessment': (_) => page('ASSESSMENT SCREEN'),
        '/history': (_) => page('HISTORY SCREEN'),
      },
    );
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pumpAndSettle();
  }

  Future<void> pickItem(WidgetTester tester, String label) async {
    await openApp(tester);
    await openDrawer(tester);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('CASE-030: 9-dots icon opens the drawer with its options', (
    tester,
  ) async {
    await openApp(tester);
    await openDrawer(tester);

    for (final label in [
      'Dashboard',
      'Voice',
      'Start Assessment',
      'Past Assessments',
      'History',
      'Get Help',
      'Profile',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
  });

  testWidgets('CASE-031: Dashboard', (tester) async {
    await pickItem(tester, 'Dashboard');

    expect(find.text('DASHBOARD SCREEN'), findsOneWidget);
    expect(find.text('Past Assessments'), findsNothing); // drawer closed
  });

  testWidgets('CASE-032: Voice', (tester) async {
    await pickItem(tester, 'Voice');

    expect(find.text('VOICE SCREEN'), findsOneWidget);
    expect(find.text('Past Assessments'), findsNothing);
  });

  testWidgets('CASE-033: Start Assessment', (tester) async {
    await pickItem(tester, 'Start Assessment');

    expect(find.text('ASSESSMENT SCREEN'), findsOneWidget);
    expect(find.text('Past Assessments'), findsNothing);
  });

  testWidgets('CASE-034: Past Assessments', (tester) async {
    await pickItem(tester, 'Past Assessments');

    // Screen title (its content needs a login, so only the screen is checked).
    expect(find.text('My Assessments'), findsOneWidget);
    expect(find.text('Start Assessment'), findsNothing);
  });

  testWidgets('CASE-035: History', (tester) async {
    await pickItem(tester, 'History');

    expect(find.text('HISTORY SCREEN'), findsOneWidget);
    expect(find.text('Past Assessments'), findsNothing);
  });

  testWidgets('CASE-036: Get Help', (tester) async {
    await pickItem(tester, 'Get Help');

    expect(find.text('How would you like to get help?'), findsOneWidget);
    expect(find.text('Start Assessment'), findsNothing);
  });

  testWidgets('CASE-037: Profile opens the profile sheet', (tester) async {
    await pickItem(tester, 'Profile');

    // It is a bottom sheet, not a separate screen.
    expect(find.text('Upload a photo'), findsOneWidget);
    expect(find.text('Emergency contact'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Remove account'), findsOneWidget);
  });

  testWidgets('CASE-038: tapping outside closes the drawer', (tester) async {
    await openApp(tester);
    await openDrawer(tester);

    expect(find.text('Dashboard'), findsOneWidget);

    // The drawer is at most 320 wide, so x = 780 is outside it.
    await tester.tapAt(const Offset(780, 300));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('HOME SCREEN'), findsOneWidget);
  });

  testWidgets('CASE-069 (dialog only): Log out asks to confirm, Cancel stays', (
    tester,
  ) async {
    await pickItem(tester, 'Profile');
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to logout?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to logout?'), findsNothing);
    expect(find.text('Log out'), findsOneWidget); // still on the sheet
  });

  testWidgets('CASE-070: Remove account, then Cancel keeps the account', (
    tester,
  ) async {
    await pickItem(tester, 'Profile');
    await tester.tap(find.text('Remove account'));
    await tester.pumpAndSettle();

    expect(find.text('Remove account?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Remove account?'), findsNothing);
    expect(find.text('Log out'), findsOneWidget); // still on the sheet
  });
}