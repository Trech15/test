import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared mood detection + direct Supabase save.
/// Put this file in lib/services/mood_service.dart
class MoodService {
  // Order = priority. First match wins. Whole-word matching only.
  static final List<MapEntry<String, RegExp>> _rules = [
    MapEntry(
      'Overwhelmed',
      RegExp(
        r"\b(overwhelm(ed|ing)|too much|can'?t handle|cannot handle|so much work)\b",
      ),
    ),
    MapEntry(
      'Anxious',
      RegExp(
        r"\b(anxious|anxiety|nervous|worried|worry|panic(king)?|scared|afraid)\b",
      ),
    ),
    MapEntry(
      'Stressed',
      RegExp(r"\b(stress(ed|ful|ing)?|pressure(d)?|deadlines?)\b"),
    ),
    MapEntry(
      'Tired',
      RegExp(
        r"\b(tired|exhausted|sleepy|fatigued|drained|burn(ed|t) out|no energy)\b",
      ),
    ),
    MapEntry(
      'Sad',
      RegExp(
        r"\b(sad|unhappy|depressed|lonely|feel(ing)? down|not (good|okay|ok|fine))\b",
      ),
    ),
    MapEntry('Angry', RegExp(r"\b(angry|mad|furious|frustrated|irritated)\b")),
    MapEntry(
      'Unfocused',
      RegExp(
        r"\b(unfocused|distracted|concentration|(can'?t|cannot|hard to) (focus|concentrate))\b",
      ),
    ),
    MapEntry('Excited', RegExp(r"\b(excited|exciting)\b")),
    MapEntry('Happy', RegExp(r"\b(happy|great|good|joyful)\b")),
    MapEntry('Calm', RegExp(r"\b(calm|relaxed|peaceful)\b")),
  ];

  /// Returns null when no mood is found (never guesses "Stressed").
  static String? detect(String message) {
    final text = message.toLowerCase();
    for (final rule in _rules) {
      if (rule.value.hasMatch(text)) return rule.key;
    }
    return null;
  }

  /// Saves straight to mood_entries with the logged-in user's session.
  static Future<bool> saveDirectly({
    required String mood,
    required String question,
    String? aiResponse,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('MOOD: cannot save - no logged-in user');
      return false;
    }

    try {
      await Supabase.instance.client.from('mood_entries').insert({
        'user_id': user.id,
        'mood': mood,
        'selected_moods': [mood],
        'question': question.trim(),
        if (aiResponse != null && aiResponse.trim().isNotEmpty)
          'ai_response': aiResponse.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('MOOD: ✅ direct save ok ($mood)');
      return true;
    } catch (e) {
      debugPrint('MOOD ERROR (direct save): $e');
      return false;
    }
  }
}
