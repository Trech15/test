import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'mood_service.dart';

/// Put this file in lib/services/bubble_chat_service.dart
///
/// The one place the floating bubble talks to the Flask `/chat` endpoint.
/// It sends exactly the same payload as ChatPage, so crisis detection, the
/// alert email, mood saving and chat_history all behave the same as before.
class BubbleChatService {
  BubbleChatService._();

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization':
        'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
  };

  /// Last [limit] saved messages, oldest first, as {'sender', 'text'} maps
  /// ('You' or 'Bot'), the same shape ChatPage uses.
  static Future<List<Map<String, String>>> loadHistory({int limit = 30}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await Supabase.instance.client
          .from('chat_history')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = <Map<String, String>>[];

      // Rows came newest first; walk them backwards so the chat reads
      // oldest to newest.
      for (final row in rows.reversed) {
        final message = row['message']?.toString() ?? '';
        final reply = row['response']?.toString() ?? '';
        if (message.isNotEmpty) {
          messages.add({'sender': 'You', 'text': message});
        }
        if (reply.isNotEmpty) {
          messages.add({'sender': 'Bot', 'text': reply});
        }
      }
      return messages;
    } catch (e) {
      debugPrint('CHAT SERVICE: could not load history: $e');
      return [];
    }
  }

  /// Sends one typed message and returns the bot's reply.
  /// Throws an [Exception] with a readable message if it fails.
  static Future<String> send(String message) async {
    final text = message.trim();
    if (text.isEmpty) throw Exception('Message is empty.');

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('You are not logged in.');

    final mood = MoodService.detect(text);

    debugPrint('CHAT SERVICE: sending to ${ApiConfig.backendUrl}/chat');

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.backendUrl}/chat'),
            headers: _headers,
            body: jsonEncode({
              'message': text,
              'user_id': user.id,
              'user_name':
                  (user.userMetadata?['full_name'] ??
                          user.userMetadata?['name'] ??
                          '')
                      .toString(),
              'mood': mood,
              'selected_moods': mood != null ? [mood] : [],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception(
          'Backend returned ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      final reply =
          decoded['response']?.toString() ?? 'Sorry, I could not process that.';
      final moodSaved = decoded['mood_saved'] == true;

      // Flask should save the mood; if it says it did not, try directly.
      if (mood != null && !moodSaved) {
        await MoodService.saveDirectly(
          mood: mood,
          question: text,
          aiResponse: reply,
        );
      }

      return reply;
    } catch (e) {
      // Flask unreachable: still save the mood so the dashboard works.
      if (mood != null) {
        await MoodService.saveDirectly(mood: mood, question: text);
      }
      throw Exception('Could not reach the assistant. Please try again.');
    }
  }
}
