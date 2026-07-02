import 'dart:ui';
import 'package:flutter/material.dart';

class VoltVaultTheme {
  // Brand Colors
  static const Color primaryNeoMint = Color(0xFF0DF58C);
  static const Color secondaryCyberBlue = Color(0xFF1A8CFF);
  static const Color alertAmber = Color(0xFFFFB300);
  static const Color alertRed = Color(0xFFFF3333);
  static const Color alertGreen = Color(0xFF0DF58C);

  // Background Colors (Obsidian Gradient)
  static const Color bgObsidianDark = Color(0xFF0F1115);
  static const Color bgObsidianLight = Color(0xFF171A21);

  // Text Colors
  static const Color textPrimary = Color(0xFFF5F6F8);
  static const Color textSecondary = Color(0xFFA0A5B5);
  static const Color textMuted = Color(0xFF6B7280);

  // Obsidian Background Gradient
  static const LinearGradient obsidianGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgObsidianDark, bgObsidianLight],
  );

  // Neo-Mint Electric Accent Gradient
  static const LinearGradient electricGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryNeoMint, secondaryCyberBlue],
  );

  // Glassmorphic Panel Decoration
  static BoxDecoration glassCardDecoration({
    double borderRadius = 16.0,
    Color borderColor = const Color(0x1FFFFFFF),
  }) {
    return BoxDecoration(
      color: const Color(0x0CFFFFFF), // Ultra-low opacity white
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  // Obsidian Dark Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryNeoMint,
      scaffoldBackgroundColor: bgObsidianDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeoMint,
        secondary: secondaryCyberBlue,
        background: bgObsidianDark,
        surface: bgObsidianLight,
        error: alertRed,
      ),
      fontFamily: 'Montserrat',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: primaryNeoMint,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryNeoMint, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: alertRed, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryNeoMint,
        foregroundColor: Colors.black,
      ),
    );
  }
}
