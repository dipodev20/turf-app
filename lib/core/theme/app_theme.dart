import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color bg = Color(0xFFF2F2F7);
  static const Color white = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF5B5BD6);
  static const Color accent2 = Color(0xFF7C7CFF);
  static const Color red = Color(0xFFFF3B30);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color gold = Color(0xFFFFD700);
  static const Color purple = Color(0xFFAF52DE);
  static const Color blue = Color(0xFF007AFF);
  static const Color t1 = Color(0xFF0D0D0D);
  static const Color t2 = Color(0xFF3A3A3A);
  static const Color t3 = Color(0xFF8A8A8E);
  static const Color t4 = Color(0xFFC0C0C5);
  static const Color sep = Color(0x12000000);
  static const Color darkBg = Color(0xFF0F0F18);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: t1,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: accent,
        unselectedItemColor: t4,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t1,
          foregroundColor: white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
