import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Put this file in lib/services/home_route.dart
///
/// Decides the first screen after login:
///  - first time (the student has no assessment yet) -> '/assessment'
///  - everyone else                                  -> '/voice_input'
///  - not logged in                                  -> '/login'
class HomeRoute {
  HomeRoute._();

  static const String firstTime = '/assessment';
  static const String returning = '/voice_input';

  static Future<String> resolve() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '/login';

    try {
      final rows = await Supabase.instance.client
          .from('stress_assessments')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      return rows.isEmpty ? firstTime : returning;
    } catch (e) {
      // If the check fails, do not trap a returning student in the assessment.
      debugPrint('HOME ROUTE: check failed -> $e');
      return returning;
    }
  }
}