import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';
import '../models/stress_data.dart';
import 'help_options_screen.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  StressData? stressData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is StressData) {
      stressData = args;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AppMenuButton(color: AppTheme.darkColor),
        leadingWidth: AppMenu.leadingWidthFor(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              'ANALYSIS COMPLETE',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF999999),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your Stress Level',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 48),
            // Circular Progress Indicator - Dynamic
            Center(
              child: CircularPercentIndicator(
                radius: 120,
                lineWidth: 16,
                percent: (stressData?.stressLevel ?? 0) / 100,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stressData?.stressCategory ?? 'UNKNOWN',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: stressData?.stressColor ?? AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stressData?.stressLevel.toStringAsFixed(1) ?? '0'}%',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                      ),
                    ),
                  ],
                ),
                progressColor: stressData?.stressColor ?? AppTheme.primaryColor,
                backgroundColor: const Color(0xFFFFECCC),
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ),
            const SizedBox(height: 48),
            // Stress Level Explanation
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (stressData?.stressColor ?? AppTheme.primaryColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (stressData?.stressColor ?? AppTheme.primaryColor)
                      .withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getExplanation(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.darkColor,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Stress Factors
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Text(
                    'Stress Factors',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStressFactor(
                    'Academic Pressure',
                    stressData?.factors[0] ?? 0,
                  ),
                  const SizedBox(height: 16),
                  _buildStressFactor(
                    'Sleep Quality',
                    stressData?.factors[1] ?? 0,
                  ),
                  const SizedBox(height: 16),
                  _buildStressFactor(
                    'Social Anxiety',
                    stressData?.factors[2] ?? 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Let the student choose: guidance, or the AI assistant.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HelpOptionsScreen(stressData: stressData),
                    ),
                  );
                },
                child: const Text('Get Help Now →'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back to Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getExplanation() {
    final level = stressData?.stressLevel ?? 0;
    if (level < 30) {
      return '✓ Your stress levels are healthy. Continue maintaining your current stress management practices and healthy lifestyle habits.';
    } else if (level < 60) {
      return '⚠ You\'re experiencing moderate stress. Consider trying relaxation techniques, exercise, or chatting with our AI assistant for personalized recommendations.';
    } else {
      return '🚨 High stress levels detected. Please prioritize self-care, consider reaching out to counseling services, or use our 24/7 chat support for immediate assistance.';
    }
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
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkColor,
              ),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(
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