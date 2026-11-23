import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/stress_data.dart';
import '../theme/app_theme.dart';
import 'help_options_screen.dart';

/// Put this file in lib/screens/guidance_card.dart
///
/// Shown on the dashboard. Tapping it opens the help options screen, where the
/// student picks guidance (send request / call / email) or the AI assistant.
/// Pass the latest assessment (or null if there is none) so it can be shared
/// with guidance when the student chooses to.
class GuidanceCard extends StatelessWidget {
  const GuidanceCard({Key? key, this.stressData, this.highlight = false})
    : super(key: key);

  final StressData? stressData;

  /// Gives the card a colored border, used when the latest stress is high.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? const Color(0xFFE74C3C) : AppTheme.primaryColor;

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HelpOptionsScreen(stressData: stressData),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: highlight
                ? Border.all(color: accent.withOpacity(0.5), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.support_agent, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need someone to talk to?',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reach guidance or chat with the assistant.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
