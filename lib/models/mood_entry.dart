class MoodEntry {
  final String id;
  final String userId;
  final String mood;
  final String? question; // The question/text they asked
  final String? aiResponse; // The AI's response
  final List<String>? selectedMoods; // Tags they selected
  final DateTime createdAt;

  MoodEntry({
    required this.id,
    required this.userId,
    required this.mood,
    this.question,
    this.aiResponse,
    this.selectedMoods,
    required this.createdAt,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      // id can be an int (bigint column) or a String (uuid column).
      // The old `as String` cast crashed on int ids, which made the
      // whole mood list fail to load.
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      mood: (json['mood']?.toString().trim().isNotEmpty ?? false)
          ? json['mood'].toString()
          : 'Unknown',
      question: json['question']?.toString(),
      aiResponse: json['ai_response']?.toString(),
      selectedMoods: (json['selected_moods'] as List<dynamic>?)
          ?.where((e) => e != null)
          .map((e) => e.toString())
          .toList(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'mood': mood,
      'question': question,
      'ai_response': aiResponse,
      'selected_moods': selectedMoods,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
