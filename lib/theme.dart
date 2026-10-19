import 'package:flutter/material.dart';

const bingeYellow = Color(0xFFFFD600);
const bingePurple = Color(0xFF7C3AED);
const bingeDeepPurple = Color(0xFF4C1D95);
const bingeBackground = Color(0xFF050308);
const bingeSurface = Color(0xFF0E0B14);
const bingeRaised = Color(0xFF17122A);
const bingeTextSecondary = Color(0xFFB8B3C9);
const bingeTextTertiary = Color(0xFF7C7790);
const bingeDanger = Color(0xFFFF5C6C);
const bingeDarkBg = bingeSurface;
const bingeFieldBg = bingeRaised;

ThemeData buildBingeTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: bingeBackground,
    colorScheme: const ColorScheme.dark(
      primary: bingeYellow,
      secondary: bingePurple,
      surface: bingeBackground,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      fontFamily: 'Inter',
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bingeFieldBg,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 24),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: bingeDeepPurple, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: bingeYellow, width: 3),
      ),
    ),
  );
}
