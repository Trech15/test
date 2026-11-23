import 'package:capstone/widgets/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Profile (CASE-065 to CASE-071). The profile is a bottom sheet
/// (ProfileSheet in app_menu.dart), not a separate screen.
///
/// Not testable here (needs Supabase / device):
///  - CASE-065 / 066: picking and uploading a photo (gallery + storage).
///  - CASE-068: saving the emergency contact (the editor loads from Supabase).
///  - CASE-069 / 071: the redirect to Login after confirming.
/// Check those manually on the device. These tests cover everything up to
/// the confirmation step.
Future<void> openProfile(WidgetTester tester) async {
  await openScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => ProfileSheet.show(context),
            child: const Text('Open profile'),
          ),
        ),
      ),
    ),
  );
  await tapButton(tester, 'Open profile');
  await tester.pumpAndSettle();
}

void main() {
  prepareFonts();

  testWidgets('CASE-065 (partial): no photo set shows Upload a photo', (
    tester,
  ) async {
    await openProfile(tester);

    expect(find.text('Upload a photo'), findsOneWidget);
    expect(find.text('Change photo'), findsNothing);
  });

  testWidgets('CASE-067 (partial): Emergency contact button opens a sheet', (
    tester,
  ) async {
    await openProfile(tester);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('Emergency contact'));
    await tester.pumpAndSettle();

    // Profile sheet + emergency contact sheet.
    expect(find.byType(BottomSheet), findsNWidgets(2));
  });

  testWidgets('CASE-069 (partial): Log out asks for confirmation', (
    tester,
  ) async {
    await openProfile(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to logout?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Cancelling logout keeps the profile sheet open', (tester) async {
    await openProfile(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to logout?'), findsNothing);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('CASE-070: cancelling Remove Account keeps the account', (
    tester,
  ) async {
    await openProfile(tester);

    await tester.tap(find.text('Remove account'));
    await tester.pumpAndSettle();
    expect(find.text('Remove account?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Remove account?'), findsNothing);
    expect(find.text('Log out'), findsOneWidget); // still on the profile
  });

  testWidgets(
    'CASE-071 (partial): Delete forever stays disabled until DELETE is typed',
    (tester) async {
      await openProfile(tester);

      await tester.tap(find.text('Remove account'));
      await tester.pumpAndSettle();

      final deleteButton = find.widgetWithText(TextButton, 'Delete forever');
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'delete me');
      await tester.pump();
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);
    },
  );
}