import 'package:flutter/material.dart';

// Model to store stress data
class StressData {
  final double stressLevel; // 0-100 (from score)
  final String stressCategory; // Low, Moderate, High
  final Color stressColor;
  final List<double> factors; // [academic, sleep, social]
  final DateTime timestamp;

  StressData({
    required this.stressLevel,
    required this.stressCategory,
    required this.stressColor,
    required this.factors,
    required this.timestamp,
  });

  // Create from score (0-100)
  factory StressData.fromScore(int score, DateTime timestamp) {
    final stressLevel = score.toDouble();
    String category;
    Color color;

    if (stressLevel < 30) {
      category = 'Low';
      color = const Color(0xFF27AE60);
    } else if (stressLevel < 60) {
      category = 'Moderate';
      color = const Color(0xFFFDB913);
    } else {
      category = 'High';
      color = const Color(0xFFE74C3C);
    }

    // Estimate factors based on score (you can refine this)
    final academic = (stressLevel / 100) * 0.8;
    final sleep = (stressLevel / 100) * 0.7;
    final social = (stressLevel / 100) * 0.6;

    return StressData(
      stressLevel: stressLevel,
      stressCategory: category,
      stressColor: color,
      factors: [academic, sleep, social],
      timestamp: timestamp,
    );
  }

  static Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'low':
        return const Color(0xFF27AE60);
      case 'moderate':
        return const Color(0xFFFDB913);
      case 'high':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF2D7A6B);
    }
  }
}
