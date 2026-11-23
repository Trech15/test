import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Put this file in lib/theme/app_theme.dart (replaces the old one).
///
/// Look: deep forest green bars, soft mint background, white cards with a
/// thin green outline, rounded corners and a rounded font (Quicksand).
class AppTheme {
  AppTheme._();

  // ---- colors ----
  static const Color primaryColor = Color(0xFF14453E); // deep forest green
  static const Color darkColor = Color(0xFF12302B); // text
  static const Color lightColor = Color(0xFFF2FAF6); // page background (mint)
  static const Color accentColor = Color(0xFFFDB913); // highlights / factor bars
  static const Color softGreen = Color(0xFF78A099); // secondary green
  static const Color mint = Color(0xFFD0E8DC); // chips, soft fills

  static const double radius = 14;

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
      surface: Colors.white,
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: primaryColor.withOpacity(0.35)),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightColor,
      primaryColor: primaryColor,
      textTheme: GoogleFonts.quicksandTextTheme().apply(
        bodyColor: darkColor,
        displayColor: darkColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.quicksand(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: GoogleFonts.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: GoogleFonts.quicksand(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: GoogleFonts.quicksand(color: const Color(0xFF8AA39D)),
        prefixIconColor: primaryColor,
        suffixIconColor: primaryColor,
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: mint,
        side: const BorderSide(color: primaryColor),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.quicksand(
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dividerColor: primaryColor.withOpacity(0.12),
    );
  }

  /// Same theme under the other name apps often use in main.dart.
  static ThemeData get lightTheme => theme;
}