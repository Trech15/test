import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'mood_service.dart';

/// Result of analyzing a conversation.
class AnalysisResult {
  AnalysisResult({required this.advice, required this.moods});

  final String advice;
  final List<String> moods;
}

/// Put this file in lib/services/analysis_service.dart
///
/// Shared by every screen that has a conversation (Chat page, and any other
/// voice/text screen) so "Analyze" behaves the same everywhere.
///
/// A "turn" is a map like {'role': 'user' | 'ai', 'text': '...'}.
class AnalysisService {
  // Server address comes from lib/config/api_config.dart
  static const String backendUrl = ApiConfig.backendUrl;

  // Render's free tier sleeps when idle and can take a minute or more to
  // wake up, so these timeouts are generous.
  static const Duration _wakeTimeout = Duration(seconds: 90);
  static const Duration _requestTimeout = Duration(seconds: 90);

  /// Flask checks this token to know which user is asking (same as ChatPage).
  /// Read fresh on every call so a refreshed session is used.
  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization':
        'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
  };

  /// Every mood the student mentioned in their own lines.
  static List<String> detectMoods(List<Map<String, String>> turns) {
    final moods = <String>[];

    for (final turn in turns) {
      if (turn['role'] != 'user') continue;

      final mood = MoodService.detect(turn['text'] ?? '');
      if (mood != null && !moods.contains(mood)) moods.add(mood);
    }

    return moods;
  }

  /// Pings the backend so a sleeping Render service starts waking up.
  /// Never throws: if it fails, the real request is still attempted.
  static Future<void> _wakeServer() async {
    try {
      final started = DateTime.now();

      final res = await http
          .get(Uri.parse('$backendUrl/test'))
          .timeout(_wakeTimeout);

      final seconds = DateTime.now().difference(started).inSeconds;

      debugPrint('☀️ Server awake (status ${res.statusCode}, ${seconds}s)');
    } catch (e) {
      debugPrint('☀️ Warm-up ping failed (will still try): $e');
    }
  }

  /// Sends the whole conversation to the backend and returns the advice.
  /// Throws an Exception with a readable message if something goes wrong.
  static Future<AnalysisResult> analyze(List<Map<String, String>> turns) async {
    debugPrint('ANALYSIS SERVICE v2');

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    final moods = detectMoods(turns);

    final conversation = turns
        .map((t) => '${t['role'] == 'user' ? 'Student' : 'AI'}: ${t['text']}')
        .join('\n');

    final message =
        'Below is a conversation between a student and a supportive '
        'AI assistant. Based on what the student shared, explain what the '
        'main problem is and give clear, practical steps the student can '
        'do now to deal with it.\n\n$conversation';

    final body = jsonEncode({
      'message': message,
      'user_id': user.id,
      'user_name':
          (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '')
              .toString(),
      // No mood is sent so this request is not counted as a new mood entry.
      // 'save': false and 'analysis': true tell the backend not to store
      // this request or add it to the chat memory.
      'mood': null,
      'selected_moods': [],
      'save': false,
      'analysis': true,
    });

    Future<http.Response> send() {
      return http
          .post(
            Uri.parse('$backendUrl/chat'),
            headers: _authHeaders,
            body: body,
          )
          .timeout(_requestTimeout);
    }

    debugPrint('🧠 ANALYZE → $backendUrl/chat | moods=$moods');

    // 1. Wake the server (Render free tier).
    await _wakeServer();

    // 2. Send the request, retrying once on network errors.
    http.Response response;

    try {
      try {
        response = await send();
      } on TimeoutException {
        debugPrint('⏱️ Analyze timed out, retrying once...');
        response = await send();
      } on http.ClientException catch (e) {
        debugPrint('🔌 Connection dropped ($e), retrying once...');
        response = await send();
      }

      // 3. Expired login token: refresh the session and retry once.
      if (response.statusCode == 401) {
        debugPrint('🔑 Got 401, refreshing session and retrying once...');

        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (e) {
          debugPrint('🔑 Session refresh failed: $e');
        }

        response = await send();
      }
    } on TimeoutException {
      throw Exception(
        'The server took too long to answer. It may be waking up. '
        'Please tap Analyze again in a moment.',
      );
    } catch (e) {
      throw Exception('Could not reach the backend at $backendUrl ($e)');
    }

    debugPrint('📥 Flask ${response.statusCode}: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Backend returned ${response.statusCode}: ${response.body}',
      );
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Backend did not return valid JSON: ${response.body}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response from backend');
    }

    final advice = decoded['response']?.toString().trim() ?? '';

    if (advice.isEmpty) {
      throw Exception('The backend returned an empty response');
    }

    return AnalysisResult(advice: advice, moods: moods);
  }

  /// Saves the analyzed session so it appears in the History screen.
  /// Throws if the save fails (for example the table does not exist yet).
  static Future<void> saveSession({
    required List<Map<String, String>> turns,
    required List<String> moods,
    required String advice,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    await Supabase.instance.client.from('voice_sessions').insert({
      'user_id': user.id,
      'conversation': turns,
      'mood': moods.isNotEmpty ? moods.first : null,
      'advice': advice,
    });

    debugPrint('💾 session saved to history');
  }
}
