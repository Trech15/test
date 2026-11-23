import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

class AdviceScreen extends StatefulWidget {
  const AdviceScreen({Key? key}) : super(key: key);

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  Map<String, dynamic>? inputData;
  String? _aiResponse;
  bool _hasLoadedInput = false;

  bool _isSaved = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _recommendations = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasLoadedInput) {
      return;
    }

    _hasLoadedInput = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      inputData = Map<String, dynamic>.from(args);
      _aiResponse = args['aiResponse']?.toString();
      _generateRecommendations();
    }
  }

  void _generateRecommendations() {
    final moods =
        (inputData?['moods'] as List?)
            ?.map((mood) => mood.toString())
            .toList() ??
        [];

    final text = inputData?['text'] as String? ?? '';

    List<Map<String, dynamic>> recommendations = [];

    for (String mood in moods) {
      switch (mood.toLowerCase()) {
        case 'anxious':
          recommendations.add({
            'icon': Icons.air,
            'title': '5-min Breathing',
            'subtitle': 'Box breathing to calm your nervous system',
            'color': AppTheme.primaryColor,
            'type': 'breathing',
          });
          break;
        case 'overwhelmed':
          recommendations.add({
            'icon': Icons.schedule,
            'title': 'Study Schedule',
            'subtitle': 'Break tasks into 25-min Pomodoro sessions',
            'color': const Color(0xFF3498DB),
            'type': 'study_schedule',
          });
          break;
        case 'tired':
          recommendations.add({
            'icon': Icons.nights_stay,
            'title': 'Sleep Hygiene',
            'subtitle': 'Aim for 7-8 hrs. Avoid screens 1hr before bed',
            'color': const Color(0xFF9B59B6),
            'type': 'sleep_hygiene',
          });
          break;
        case 'stressed':
          recommendations.add({
            'icon': Icons.self_improvement,
            'title': 'Meditation',
            'subtitle': '10-min guided meditation to reduce stress',
            'color': const Color(0xFF16A085),
            'type': 'meditation',
          });
          break;
        case 'unfocused':
          recommendations.add({
            'icon': Icons.directions_run,
            'title': 'Exercise',
            'subtitle': '30-min physical activity to improve focus',
            'color': const Color(0xFFE67E22),
            'type': 'exercise',
          });
          break;
      }
    }

    if (recommendations.isEmpty) {
      recommendations = [
        {
          'icon': Icons.air,
          'title': '5-min Breathing',
          'subtitle': 'Box breathing to calm your nervous system',
          'color': AppTheme.primaryColor,
          'type': 'breathing',
        },
        {
          'icon': Icons.schedule,
          'title': 'Study Schedule',
          'subtitle': 'Break tasks into 25-min Pomodoro sessions',
          'color': const Color(0xFF3498DB),
          'type': 'study_schedule',
        },
        {
          'icon': Icons.nights_stay,
          'title': 'Sleep Hygiene',
          'subtitle': 'Aim for 7-8 hrs. Avoid screens 1hr before bed',
          'color': const Color(0xFF9B59B6),
          'type': 'sleep_hygiene',
        },
      ];
    }

    if (mounted) {
      setState(() {
        _recommendations = recommendations;
      });
    }
  }

  Future<void> _saveToDatabase() async {
    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not logged in')));
        setState(() => _isSaving = false);
        return;
      }

      final moods =
          (inputData?['moods'] as List?)
              ?.map((mood) => mood.toString())
              .toList() ??
          [];

      final assessmentRes = await Supabase.instance.client
          .from('stress_assessments')
          .select('id')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (!mounted) return;

      if (assessmentRes.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No assessment found')));
        setState(() => _isSaving = false);
        return;
      }

      final assessmentId = assessmentRes[0]['id'] as int;

      for (String mood in moods) {
        await Supabase.instance.client.from('mood_tags').insert({
          'user_id': user.id,
          'mood': mood,
          'assessment_id': assessmentId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      for (Map<String, dynamic> rec in _recommendations) {
        await Supabase.instance.client.from('recommendations').insert({
          'user_id': user.id,
          'assessment_id': assessmentId,
          'recommendation_type': rec['type'],
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;

      setState(() {
        _isSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recommendations saved to your profile!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } catch (e) {
      print('Error saving to database: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
          'Recommendations',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Personalized for you',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_aiResponse != null && _aiResponse!.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                  ),
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
                        Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'AI Assistant Advice',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _aiResponse!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.darkColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 8),

            Text(
              'Based on your mood: ${(inputData?['moods'] as List?)?.join(', ') ?? 'General'}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF999999),
              ),
            ),

            const SizedBox(height: 16),

            ..._recommendations.map((rec) {
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
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (rec['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(rec['icon'], color: rec['color'], size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec['title'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rec['subtitle'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: rec['color']),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveToDatabase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaved
                      ? Colors.grey
                      : AppTheme.primaryColor,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _isSaved ? 'Saved to Profile ✓' : 'Save to Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}