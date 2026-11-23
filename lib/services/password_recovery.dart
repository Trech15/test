import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Put this file in lib/services/password_recovery.dart
///
/// When the student taps the reset link in their email, the phone opens the
/// app and Supabase signs them in with a special "password recovery" event.
/// This catches that event and opens the "Set a new password" screen.
///
/// Setup in main.dart, right after `await Supabase.initialize(...)`:
///
///   PasswordRecovery.listen(navigatorKey);
///
/// and give the same navigatorKey to MaterialApp(navigatorKey: ...) and add
/// the route  '/reset-password': (_) => const ResetPasswordScreen().
class PasswordRecovery {
  PasswordRecovery._();

  static bool _pending = false;
  static StreamSubscription<AuthState>? _sub;

  /// True once if the recovery link arrived before the app had a navigator
  /// (the app was closed when the link was tapped). The splash screen checks
  /// this and goes to the reset screen instead of login or home.
  static bool consumePending() {
    final value = _pending;
    _pending = false;
    return value;
  }

  static void listen(GlobalKey<NavigatorState> navigatorKey) {
    _sub?.cancel();

    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event != AuthChangeEvent.passwordRecovery) return;

      debugPrint('🔑 Password recovery link opened');

      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        _pending = true;
        return;
      }

      navigator.pushNamedAndRemoveUntil('/reset-password', (route) => false);
    });
  }
}