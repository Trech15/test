import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String webClientId =
      '736325107957-0dm2da8vnl5uqagipdp5rj1opn4g2ufb.apps.googleusercontent.com';

  static const String iosClientId =
      'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

  static SupabaseClient get client => Supabase.instance.client;

  // ============================================================
  // CREATE USER PROFILE (if it does not exist yet)
  // ============================================================

  static Future<void> ensureProfile({
    required String userId,
    required String email,
    required String? fullName,
    String? studentId,
  }) async {
    final existing = await client
        .from('user_profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();

    // A database trigger may already have created it.
    if (existing != null) return;

    await client.from('user_profiles').insert({
      'id': userId,
      'email': email,
      'full_name': fullName ?? '',
      if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
    });
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  /// Returns true when signed in, false if the person closed the Google
  /// picker. Throws an [Exception] if sign in fails.
  static Future<bool> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId,
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? iosClientId
          : null,
    );

    await googleSignIn.signOut();

    final googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      return false;
    }

    try {
      final googleAuth = await googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google did not return an ID token.');
      }

      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Google authentication failed.');
      }

      // Was this Google account created just now?
      final createdAt = DateTime.tryParse(user.createdAt ?? '');

      final isNewAuthAccount =
          createdAt != null &&
          DateTime.now().difference(createdAt).inSeconds.abs() < 120;

      final profile = await client
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // First-time Google account without a profile.
        await ensureProfile(
          userId: user.id,
          email: user.email ?? googleUser.email,
          fullName: googleUser.displayName,
        );
      } else if (isNewAuthAccount) {
        // The database trigger already made a bare profile for this new
        // account. Fill in the details Google gave us.
        await client
            .from('user_profiles')
            .update({
              'email': user.email ?? googleUser.email,
              'full_name': googleUser.displayName ?? '',
            })
            .eq('id', user.id);
      }

      return true;
    } catch (e) {
      // Do not leave a half signed-in account behind.
      await client.auth.signOut();
      rethrow;
    }
  }
}