import 'package:flutter/material.dart';

const bingeYellow = Color(0xFFFFD600);
const bingePurple = Color(0xFF7C3AED);
const bingeDeepPurple = Color(0xFF4C1D95);
const bingeDarkBg = Color(0xFF0D0A12);
const bingeFieldBg = Color(0xFF16121F);

ThemeData buildBingeTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: bingeYellow,
      secondary: bingePurple,
      surface: Colors.black,
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
