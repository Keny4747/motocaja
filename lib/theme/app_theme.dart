import 'package:flutter/material.dart';

class AppColors {
  static const green = Color(0xFF169447);
  static const greenDark = Color(0xFF087A37);
  static const greenSoft = Color(0xFFE2F5E9);
  static const red = Color(0xFFE51C23);
  static const redSoft = Color(0xFFFFE8E8);
  static const navy = Color(0xFF111A35);
  static const muted = Color(0xFF6A7182);
  static const surface = Color(0xFFF7F8FA);
  static const border = Color(0xFFE8EAF0);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
    ),
  );
}
