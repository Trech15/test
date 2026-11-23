import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stress_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

/// Put this file in lib/screens/assessment_history_screen.dart
///
/// Lists every assessment the logged-in user has taken. Tapping one opens
/// the full assessment: each question and the answer that was chosen.

// ============================================================
// DATA
// ============================================================

class _PastAnswer {
  _PastAnswer({
    required this.question,
    required this.options,
    required this.answerIndex,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
}

class _PastAssessment {
  _PastAssessment({
    required this.score,
    required this.createdAt,
    required this.answers,
    required this.answerCount,
  });

  final int score;
  final DateTime createdAt;

  /// Questions with their options and the chosen answer. Empty for
  /// assessments saved before the questions were stored with the answers.
  final List<_PastAnswer> answers;

  /// How many answers were recorded (even when the question text is missing).
  final int answerCount;

  bool get hasDetails => answers.isNotEmpty;

  StressData get stress => StressData.fromScore(score, createdAt);

  factory _PastAssessment.fromRow(Map<String, dynamic> row) {
    final raw = row['answers'];
    final detailed = <_PastAnswer>[];
    var count = 0;

    if (raw is List) {
      count = raw.length;

      for (final item in raw) {
        if (item is! Map) continue;

        final question = item['question'];
        final options = item['options'];
        final answerIndex = item['answer_index'];

        if (question is String && options is List && answerIndex is int) {
          detailed.add(
            _PastAnswer(
              question: question,
              options: options.map((o) => o.toString()).toList(),
              answerIndex: answerIndex,
            ),
          );
        }
      }
    }

    return _PastAssessment(
      score: (row['score'] as num).toInt(),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      answers: detailed,
      answerCount: count,
    );
  }
}

// ============================================================
// LIST SCREEN
// ============================================================

class AssessmentHistoryScreen extends StatefulWidget {
  const AssessmentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AssessmentHistoryScreen> createState() =>
      _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<_PastAssessment> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('You are not logged in.');
      }

      final rows = await Supabase.instance.client
          .from('stress_assessments')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Read row by row so one bad row can't hide all the others.
      final items = <_PastAssessment>[];
      for (final row in rows) {
        try {
          items.add(_PastAssessment.fromRow(row));
        } catch (e) {
          debugPrint('ASSESSMENT HISTORY: bad row skipped -> $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ASSESSMENT HISTORY: load failed -> $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your assessments.';
        _isLoading = false;
      });
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
          'My Assessments',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.darkColor,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 56,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No assessments yet',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take your first assessment from the dashboard and your answers will show up here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildCard(_items[index]),
      ),
    );
  }

  Widget _buildCard(_PastAssessment item) {
    final stress = item.stress;

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _AssessmentDetailScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stress.stressColor.withOpacity(0.12),
                ),
                child: Center(
                  child: Text(
                    '${item.score}%',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: stress.stressColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(item.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    Text(
                      DateFormat('h:mm a').format(item.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${stress.stressCategory} stress · ${item.answerCount} answers',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: stress.stressColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL SCREEN
// ============================================================

class _AssessmentDetailScreen extends StatelessWidget {
  const _AssessmentDetailScreen({required this.item});

  final _PastAssessment item;

  @override
  Widget build(BuildContext context) {
    final stress = item.stress;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: const AppMenuButton(),
        leadingWidth: AppMenu.leadingWidthFor(context),
        title: Text(
          DateFormat('MMM d, yyyy').format(item.createdAt),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ---------------- SUMMARY ----------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.score}%',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: stress.stressColor,
                        ),
                      ),
                      Text(
                        '${stress.stressCategory} stress',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: stress.stressColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(item.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF999999),
                        ),
                      ),
                      Text(
                        '${item.answerCount} questions',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------------- QUESTIONS ----------------
            if (!item.hasDetails)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  'The questions for this assessment were not saved because it was taken before this feature was added. Your score is shown above. New assessments will show every question and the answer you chose.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.darkColor,
                  ),
                ),
              )
            else
              ...List.generate(item.answers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildQuestionCard(i, item.answers[i]),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, _PastAnswer answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION ${index + 1}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF999999),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer.question,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(answer.options.length, (i) {
            final selected = i == answer.answerIndex;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryColor
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      answer.options[i],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF777777),
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}