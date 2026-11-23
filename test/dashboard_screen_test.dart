import 'package:capstone/screens/dashboard_screen.dart';
import 'package:capstone/widgets/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// CASE-043 to CASE-045 (Dashboard).
///
/// Supabase is not initialized in these tests. DashboardScreen guards its
/// Supabase reads, so it renders the empty (no user / no data) state.
void main() {
  prepareFonts();

  testWidgets('CASE-043: dashboard opens and shows its sections', (
    tester,
  ) async {
    await openScreen(tester, const DashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.textContaining('Good '), findsOneWidget); // greeting
    expect(find.text('MOOD HISTORY'), findsOneWidget);
    expect(
      find.text('No mood entries yet. Start tracking your mood!'),
      findsOneWidget,
    );
    // Stress level and factors need real data from Supabase (not covered).
  });

  testWidgets('CASE-044: back arrow returns to the previous screen', (
    tester,
  ) async {
    await openScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
              child: const Text('Go to dashboard'),
            ),
          ),
        ),
      ),
    );

    await tapButton(tester, 'Go to dashboard');
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Go to dashboard'), findsOneWidget);
  });

  testWidgets('CASE-045: tapping the avatar opens the profile sheet', (
    tester,
  ) async {
    await openScreen(tester, const DashboardScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(UserAvatar));
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Remove account'), findsOneWidget);
  });
}