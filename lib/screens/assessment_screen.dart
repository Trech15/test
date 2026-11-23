import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stress_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({Key? key}) : super(key: key);

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  int _currentQuestion = 0;
  bool _isSubmitting = false;
  late List<int> _randomizedQuestions;

  // All 30 questions
  final List<Map<String, dynamic>> _allQuestions = [
    {
      'question': 'How often have you felt overwhelmed in the last 7 days?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Almost always'],
      'category': 'stress',
    },
    {
      'question': 'How is your sleep quality currently?',
      'options': ['Very Poor', 'Poor', 'Fair', 'Good', 'Very Good'],
      'category': 'sleep',
    },
    {
      'question': 'How would you rate your stress level?',
      'options': ['Very Low', 'Low', 'Moderate', 'High', 'Very High'],
      'category': 'stress',
    },
    {
      'question': 'How anxious do you feel in social situations?',
      'options': ['Not at all', 'A little', 'Moderately', 'Very', 'Extremely'],
      'category': 'anxiety',
    },
    {
      'question': 'How often do you exercise or engage in physical activity?',
      'options': [
        'Daily',
        '4-5 times/week',
        '2-3 times/week',
        'Once a week',
        'Never',
      ],
      'category': 'exercise',
    },
    {
      'question': 'How satisfied are you with your academic performance?',
      'options': [
        'Very Unsatisfied',
        'Unsatisfied',
        'Neutral',
        'Satisfied',
        'Very Satisfied',
      ],
      'category': 'academic',
    },
    {
      'question': 'How often do you feel pressure from school or work?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'pressure',
    },
    {
      'question': 'How well do you manage your time?',
      'options': ['Very Poorly', 'Poorly', 'Fairly', 'Well', 'Very Well'],
      'category': 'time_management',
    },
    {
      'question': 'How often do you feel lonely or isolated?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'social',
    },
    {
      'question': 'How confident are you about your future?',
      'options': [
        'Very Unconfident',
        'Unconfident',
        'Neutral',
        'Confident',
        'Very Confident',
      ],
      'category': 'confidence',
    },
    {
      'question': 'How much do you worry about your health?',
      'options': ['Not at all', 'A little', 'Moderately', 'A lot', 'Extremely'],
      'category': 'health_worry',
    },
    {
      'question': 'How often do you feel motivated to study or work?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'motivation',
    },
    {
      'question': 'How well do you handle unexpected changes or challenges?',
      'options': ['Very Poorly', 'Poorly', 'Fairly', 'Well', 'Very Well'],
      'category': 'resilience',
    },
    {
      'question': 'How often do you feel irritable or easily upset?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'irritability',
    },
    {
      'question': 'How satisfied are you with your relationships?',
      'options': [
        'Very Unsatisfied',
        'Unsatisfied',
        'Neutral',
        'Satisfied',
        'Very Satisfied',
      ],
      'category': 'relationships',
    },
    {
      'question': 'How often do you skip meals due to stress or busyness?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'eating_habits',
    },
    {
      'question': 'How is your concentration and focus?',
      'options': ['Very Poor', 'Poor', 'Fair', 'Good', 'Very Good'],
      'category': 'concentration',
    },
    {
      'question': 'How often do you feel overwhelmed by your responsibilities?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'responsibility',
    },
    {
      'question': 'How satisfied are you with your current lifestyle?',
      'options': [
        'Very Unsatisfied',
        'Unsatisfied',
        'Neutral',
        'Satisfied',
        'Very Satisfied',
      ],
      'category': 'lifestyle',
    },
    {
      'question': 'How often do you engage in hobbies or activities you enjoy?',
      'options': [
        'Daily',
        '4-5 times/week',
        '2-3 times/week',
        'Once a week',
        'Never',
      ],
      'category': 'hobbies',
    },
    {
      'question': 'How well do you maintain work-life balance?',
      'options': ['Very Poorly', 'Poorly', 'Fairly', 'Well', 'Very Well'],
      'category': 'balance',
    },
    {
      'question': 'How often do you experience headaches or body aches?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'physical_symptoms',
    },
    {
      'question': 'How comfortable are you asking for help when needed?',
      'options': [
        'Very Uncomfortable',
        'Uncomfortable',
        'Neutral',
        'Comfortable',
        'Very Comfortable',
      ],
      'category': 'help_seeking',
    },
    {
      'question': 'How often do you feel depressed or sad?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'mood',
    },
    {
      'question': 'How much caffeine or energy drinks do you consume daily?',
      'options': ['None', '1 cup', '2 cups', '3 cups', '4+ cups'],
      'category': 'caffeine',
    },
    {
      'question': 'How often do you procrastinate on important tasks?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'procrastination',
    },
    {
      'question': 'How satisfied are you with your support system?',
      'options': [
        'Very Unsatisfied',
        'Unsatisfied',
        'Neutral',
        'Satisfied',
        'Very Satisfied',
      ],
      'category': 'support',
    },
    {
      'question': 'How often do you experience panic or severe anxiety?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'panic',
    },
    {
      'question': 'How well do you handle criticism or negative feedback?',
      'options': ['Very Poorly', 'Poorly', 'Fairly', 'Well', 'Very Well'],
      'category': 'feedback_handling',
    },
    {
      'question': 'How often do you feel mentally exhausted?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      'category': 'mental_fatigue',
    },
  ];

  final Map<int, int> _answers = {};

  /// The answer shown as selected for the question on screen. It comes from
  /// _answers, so going back to an earlier question shows what was chosen.
  int? get _selectedAnswer => _answers[_currentQuestion];
  final int _questionsToShow = 10; // Show 10 random questions out of 30

  @override
  void initState() {
    super.initState();
    _randomizeQuestions();
  }

  void _randomizeQuestions() {
    // Create a list of indices and shuffle them
    List<int> indices = List<int>.generate(_allQuestions.length, (i) => i);
    indices.shuffle(Random());
    // Take only the first 10 questions
    _randomizedQuestions = indices.take(_questionsToShow).toList();
  }

  List<Map<String, dynamic>> get _questions {
    return _randomizedQuestions.map((index) => _allQuestions[index]).toList();
  }

  Future<void> _submitAssessment() async {
    if (_selectedAnswer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an answer')));
      return;
    }

    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      await _saveAssessment();
    }
  }

  void _previousQuestion() {
    if (_currentQuestion > 0) setState(() => _currentQuestion--);
  }

  /// Jump to a question you already answered (or the next unanswered one).
  void _goToQuestion(int index) {
    if (_isSubmitting) return;
    setState(() => _currentQuestion = index);
  }

  Widget _buildQuestionNav(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (int i = 0; i < total; i++) _questionDot(i)],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a number to go back and change an answer.',
          style: GoogleFonts.quicksand(
            fontSize: 12,
            color: const Color(0xFF8AA39D),
          ),
        ),
      ],
    );
  }

  Widget _questionDot(int i) {
    final isCurrent = i == _currentQuestion;
    final isAnswered = _answers.containsKey(i);
    // You can open any answered question, plus the next unanswered one.
    final canTap = !isCurrent && i <= _answers.length;

    final Color fill = isCurrent
        ? AppTheme.primaryColor
        : (isAnswered ? AppTheme.mint : Colors.white);
    final Color textColor = isCurrent
        ? Colors.white
        : ((isAnswered || canTap)
              ? AppTheme.primaryColor
              : const Color(0xFFB0B8B5));

    return GestureDetector(
      onTap: canTap ? () => _goToQuestion(i) : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(
            color: (isCurrent || isAnswered || canTap)
                ? AppTheme.primaryColor
                : const Color(0xFFD5DBD8),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            '${i + 1}',
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAssessment() async {
    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Calculate overall stress score (0-100)
      int totalScore = 0;
      int questionCount = _answers.length;

      _answers.forEach((questionIndex, answerIndex) {
        totalScore += answerIndex;
      });

      // Normalize to 0-100
      final finalScore = ((totalScore / (questionCount * 4)) * 100)
          .toInt()
          .clamp(0, 100);

      // Convert answers Map to List for JSON serialization.
      // Each answer is saved together with its question text and options,
      // because the 10 questions are picked at random. This is what lets the
      // "My Assessments" screen show the full assessment later.
      final shownQuestions = _questions;
      final answersJson = _answers.entries.map((e) {
        final q = shownQuestions[e.key];
        final options = (q['options'] as List)
            .map((o) => o.toString())
            .toList();

        return {
          'question_index': e.key,
          'bank_index': _randomizedQuestions[e.key],
          'question': q['question'],
          'options': options,
          'answer_index': e.value,
          'answer': options[e.value],
        };
      }).toList();

      // Save to Supabase
      await Supabase.instance.client.from('stress_assessments').insert({
        'user_id': user.id,
        'score': finalScore,
        'answers': answersJson,
        'total_questions': questionCount,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        final stressData = StressData.fromScore(finalScore, DateTime.now());
        Navigator.pushReplacementNamed(
          context,
          '/detection',
          arguments: stressData,
        );
      }
    } catch (e) {
      print('Error saving assessment: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving assessment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestion];
    final totalQuestions = _questions.length;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AppMenuButton(color: AppTheme.darkColor),
        leadingWidth: AppMenu.leadingWidthFor(context),
        title: Text(
          'STRESS ASSESSMENT',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentQuestion + 1} of $totalQuestions',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkColor,
                  ),
                ),
                Text(
                  '${((_currentQuestion + 1) / totalQuestions * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentQuestion + 1) / totalQuestions,
                minHeight: 8,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildQuestionNav(totalQuestions),
            const SizedBox(height: 28),
            // Question
            Text(
              question['question'],
              style: GoogleFonts.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Options
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: question['options'].length,
              itemBuilder: (context, index) {
                final option = question['options'][index];
                final isSelected = _selectedAnswer == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _answers[_currentQuestion] = index);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : const Color(0xFFE0E0E0),
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : const Color(0xFFCCCCCC),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            option,
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.darkColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            // Next Button
            Row(
              children: [
                if (_currentQuestion > 0) ...[
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : _previousQuestion,
                    child: const Text('← Back'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAssessment,
                child: _isSubmitting
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
                        _currentQuestion == _questions.length - 1
                            ? 'Submit Answers'
                            : 'Next Question →',
                        style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                      ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}