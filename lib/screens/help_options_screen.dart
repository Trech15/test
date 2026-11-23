import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/stress_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';
import 'referral_screen.dart';

/// Put this file in lib/screens/help_options_screen.dart
///
/// Shown after an assessment when the student taps "Get Help Now",
/// or from the dashboard guidance card (stressData is null there).
/// The student chooses: talk to a person at guidance, or use the AI
/// assistant by voice or typing.
class HelpOptionsScreen extends StatelessWidget {
  const HelpOptionsScreen({Key? key, this.stressData}) : super(key: key);

  final StressData? stressData;

  String? get _summary {
    final s = stressData;
    if (s == null) return null;
    return '${s.stressCategory} stress (${s.stressLevel.toStringAsFixed(0)}%)';
  }

  bool get _isHigh => (stressData?.stressLevel ?? 0) >= 60;

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
          'Get Help',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How would you like to get help?',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what feels right for you right now.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF999999),
                ),
              ),

              if (_isHigh) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE74C3C).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Your result shows high stress. Talking with someone at guidance can really help.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              _optionCard(
                context,
                icon: Icons.support_agent,
                color: AppTheme.primaryColor,
                title: 'Talk to Guidance',
                subtitle:
                    'Call or email the guidance office and talk with a real person.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReferralScreen(stressSummary: _summary),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}