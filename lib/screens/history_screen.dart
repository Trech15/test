import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Step 1: Get stress assessments
      final assessmentsRes = await Supabase.instance.client
          .from('stress_assessments')
          .select('id, score, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> historyList = [];

      // Step 2: For each assessment, get mood tags and recommendations
      for (var assessment in assessmentsRes) {
        final assessmentId = assessment['id'] as int;
        final score = assessment['score'] as int;

        // Get mood tags
        final moodsRes = await Supabase.instance.client
            .from('mood_tags')
            .select('mood')
            .eq('assessment_id', assessmentId);

        // Get recommendations
        final recsRes = await Supabase.instance.client
            .from('recommendations')
            .select('recommendation_type')
            .eq('assessment_id', assessmentId);

        // Determine stress level category
        String stressLevel = _getStressLevel(score);

        // Build mood text
        String moodText = moodsRes.isNotEmpty
            ? moodsRes.map((m) => m['mood']).join(', ')
            : 'General stress check-in';

        // Determine input type (if recommendations exist, it came from assessment)
        String inputType = recsRes.isNotEmpty ? 'Voice' : 'Text';

        historyList.add({
          'kind': 'assessment',
          'assessment_id': assessmentId,
          'stress_level': stressLevel,
          'score': score,
          'moods': moodText,
          'message': moodText,
          'input_type': inputType,
          'created_at': DateTime.parse(assessment['created_at']),
          'type': stressLevel,
        });
      }

      // Step 3: Voice sessions (conversation + the advice from Analyze)
      try {
        final voiceRes = await Supabase.instance.client
            .from('voice_sessions')
            .select('id, conversation, mood, advice, created_at')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        for (final v in voiceRes) {
          historyList.add({
            'kind': 'voice',
            'id': v['id'],
            'mood': v['mood'],
            'advice': v['advice'] ?? '',
            'conversation': v['conversation'],
            'created_at': DateTime.parse(v['created_at'].toString()).toLocal(),
          });
        }
      } catch (e) {
        // Most likely the voice_sessions table has not been created yet.
        print('Could not load voice_sessions: $e');
      }

      // Newest first, assessments and voice sessions together.
      historyList.sort(
        (a, b) => (b['created_at'] as DateTime).compareTo(
          a['created_at'] as DateTime,
        ),
      );

      if (!mounted) return;

      setState(() {
        _history = historyList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _getStressLevel(int score) {
    if (score >= 70) {
      return 'High Stress';
    } else if (score >= 40) {
      return 'Moderate Stress';
    } else {
      return 'Low Stress';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'High Stress':
        return const Color(0xFFE74C3C); // Red
      case 'Moderate Stress':
        return const Color(0xFFFDB913); // Orange/Yellow
      default:
        return const Color(0xFF27AE60); // Green
    }
  }

  IconData _getStressIcon(String type) {
    switch (type) {
      case 'High Stress':
        return Icons.sentiment_very_dissatisfied;
      case 'Moderate Stress':
        return Icons.sentiment_neutral;
      default:
        return Icons.sentiment_very_satisfied;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Check if today
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    // Check if yesterday
    else if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    // Other dates
    else {
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  // ----------------------------------------------------------
  // VOICE SESSION CARD + DETAIL
  // ----------------------------------------------------------

  Widget _buildVoiceCard(Map<String, dynamic> item) {
    final mood = (item['mood'] as String?)?.trim() ?? '';
    final advice = (item['advice'] as String?)?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showVoiceDetail(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor.withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.mic,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice Session',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkColor,
                          ),
                        ),
                        Text(
                          mood.isNotEmpty
                              ? 'Mood: $mood'
                              : 'Mood: not detected',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                advice.isEmpty ? 'No advice saved' : advice,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.darkColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatDate(item['created_at']),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoiceDetail(Map<String, dynamic> item) {
    final raw = item['conversation'];
    final turns = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final t in raw) {
        if (t is Map) turns.add(Map<String, dynamic>.from(t));
      }
    }

    final mood = (item['mood'] as String?)?.trim() ?? '';
    final advice = (item['advice'] as String?)?.trim() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.lightColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Voice Session',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(item['created_at'])}'
                    '${mood.isNotEmpty ? '  •  Mood: $mood' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'WHAT YOU CAN DO',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: const Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      advice.isEmpty ? 'No advice saved.' : advice,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.darkColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CONVERSATION',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: const Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...turns.map((t) {
                    final isUser = t['role'] == 'user';
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: const BoxConstraints(maxWidth: 290),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppTheme.primaryColor.withOpacity(0.14)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          (t['text'] ?? '').toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.4,
                            color: AppTheme.darkColor,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: const AppMenuButton(),
        leadingWidth: AppMenu.leadingWidthFor(context),
        title: Text(
          'Session History',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No history yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your past stress check-ins will appear here',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];

                if (item['kind'] == 'voice') {
                  return _buildVoiceCard(item);
                }

                final typeColor = _getTypeColor(item['type']);
                final stressIcon = _getStressIcon(item['type']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with stress level and input type
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stress level with icon
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: typeColor.withOpacity(0.2),
                                  ),
                                  child: Icon(
                                    stressIcon,
                                    color: typeColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['type'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: typeColor,
                                      ),
                                    ),
                                    Text(
                                      'Stress Level: ${item['score']}%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Input type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['input_type'] == 'Voice'
                                        ? Icons.mic
                                        : Icons.text_fields,
                                    size: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['input_type'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Moods/Message
                        Text(
                          item['moods'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.darkColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Date
                        Text(
                          _formatDate(item['created_at']),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}