import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mood_entry.dart';
import '../models/stress_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

/// Dashboard: current mood, mood history, current stress level and stress
/// factors. Everything else (assessment, history, profile...) is in the
/// dots menu on the left of the app bar.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StressData? currentStress;
  bool isLoading = true;
  List<MoodEntry> moodEntries = [];

  final Map<String, String> _moodEmojis = {
    'Anxious': '😰',
    'Overwhelmed': '😩',
    'Tired': '😴',
    'Stressed': '😣',
    'Unfocused': '😕',
    'Happy': '😊',
    'Sad': '😢',
    'Angry': '😠',
    'Calm': '😌',
    'Excited': '🤩',
    'Voice Chat Active': '🎤',
  };

  @override
  void initState() {
    super.initState();
    _loadStressData();
    _loadMoodHistory();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> _loadMoodHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('mood_entries')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(500);

      // Parse row by row so one bad row can't empty the whole list.
      final entries = <MoodEntry>[];
      for (final json in response as List) {
        try {
          entries.add(MoodEntry.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          debugPrint('MOOD LOAD: bad row skipped -> $json | $e');
        }
      }

      if (!mounted) return;
      setState(() => moodEntries = entries);
    } catch (e) {
      debugPrint('MOOD LOAD: query failed -> $e');
    }
  }

  Future<void> _loadStressData() async {
    setState(() => isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // No logged-in user: stop the spinner instead of loading forever.
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final stressRes = await Supabase.instance.client
          .from('stress_assessments')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      setState(() {
        if (stressRes.isNotEmpty) {
          final latestScore = stressRes[0]['score'] as int;
          final createdAt = DateTime.parse(
            stressRes[0]['created_at'] as String,
          );
          currentStress = StressData.fromScore(latestScore, createdAt);
        } else {
          currentStress = StressData(
            stressLevel: 0,
            stressCategory: 'No Data',
            stressColor: AppTheme.primaryColor,
            factors: [0, 0, 0],
            timestamp: DateTime.now(),
          );
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stress data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _getMoodEmoji(String mood) => _moodEmojis[mood] ?? '😐';

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (entryDate == yesterday) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    }
  }

  String _groupByDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'Today';
    if (entryDate == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Guarded: Supabase may not be initialized (e.g. in widget tests).
    User? currentUser;
    try {
      currentUser = Supabase.instance.client.auth.currentUser;
    } catch (_) {}
    final userName = UserAvatar.displayName(currentUser);

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        // Flat bottom edge: the greeting header below has the rounded corners.
        shape: const RoundedRectangleBorder(),
        // The dots menu is on the LEFT.
        leading: const AppMenuButton(),
        leadingWidth: AppMenu.leadingWidthFor(context),
        title: Text(
          'Dashboard',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => ProfileSheet.show(context).then((_) {
                if (mounted) setState(() {});
              }),
              child: const UserAvatar(),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ---------------- greeting ----------------
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(28),
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userName,
                            style: GoogleFonts.quicksand(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ---------------- content ----------------
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Current mood
                          _buildCurrentMood(),

                          // 2. Mood history (swipe left for older moods)
                          _buildMoodHistory(),
                          const SizedBox(height: 32),

                          // 3. Current stress level
                          if (currentStress != null) _buildStressLevel(),
                          const SizedBox(height: 24),

                          // 4. Stress factors
                          if (currentStress != null) _buildStressFactors(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // CURRENT MOOD
  // ============================================================

  Widget _buildCurrentMood() {
    if (moodEntries.isEmpty) return const SizedBox.shrink();
    final latest = moodEntries.first; // list is newest-first

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Text(
            _getMoodEmoji(latest.mood),
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT MOOD',
                  style: GoogleFonts.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF999999),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  latest.mood,
                  style: GoogleFonts.quicksand(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                ),
                Text(
                  _formatTime(latest.createdAt.toLocal()),
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOOD HISTORY
  // ============================================================

  Widget _buildMoodHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MOOD HISTORY',
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF999999),
                letterSpacing: 0.5,
              ),
            ),
            if (moodEntries.length > 1)
              Text(
                'Swipe for earlier  →',
                style: GoogleFonts.quicksand(
                  fontSize: 11,
                  color: const Color(0xFF999999),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (moodEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration,
            child: Center(
              child: Text(
                'No mood entries yet. Start tracking your mood!',
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              itemCount: moodEntries.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _buildMoodCard(moodEntries[index], isLatest: index == 0),
            ),
          ),
      ],
    );
  }

  Widget _buildMoodCard(MoodEntry entry, {required bool isLatest}) {
    final local = entry.createdAt.toLocal();
    final extras = entry.selectedMoods ?? <String>[];
    final shown = extras.take(2).toList();
    final hidden = extras.length - shown.length;

    return Container(
      width: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLatest
            ? Border.all(
                color: AppTheme.primaryColor.withOpacity(0.5),
                width: 1.5,
              )
            : Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
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
          Text(_getMoodEmoji(entry.mood), style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          Text(
            entry.mood,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _groupByDate(local),
            style: GoogleFonts.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.darkColor.withOpacity(0.7),
            ),
          ),
          Text(
            DateFormat('h:mm a').format(local),
            style: GoogleFonts.quicksand(fontSize: 12, color: Colors.grey[600]),
          ),
          if (shown.isNotEmpty) ...[
            const Spacer(),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final mood in shown) _moodChip(mood),
                if (hidden > 0) _moodChip('+$hidden'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _moodChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.quicksand(fontSize: 10, color: AppTheme.primaryColor),
      ),
    );
  }

  // ============================================================
  // CURRENT STRESS LEVEL
  // ============================================================

  Widget _buildStressLevel() {
    final stress = currentStress!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Stress Level',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stress.stressLevel.toStringAsFixed(1)}%',
                    style: GoogleFonts.quicksand(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: stress.stressColor,
                    ),
                  ),
                  Text(
                    stress.stressCategory,
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: stress.stressColor,
                    ),
                  ),
                ],
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stress.stressColor.withOpacity(0.1),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: stress.stressLevel / 100,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      stress.stressColor,
                    ),
                    backgroundColor: Colors.grey[200],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STRESS FACTORS
  // ============================================================

  Widget _buildStressFactors() {
    final factors = currentStress!.factors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stress Factors',
            style: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildStressFactor('Academic Pressure', factors[0]),
          const SizedBox(height: 16),
          _buildStressFactor('Sleep Quality', factors[1]),
          const SizedBox(height: 16),
          _buildStressFactor('Social Anxiety', factors[2]),
        ],
      ),
    );
  }

  Widget _buildStressFactor(String label, double percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkColor,
              ),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFE8E8E8),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
          ),
        ),
      ],
    );
  }
}