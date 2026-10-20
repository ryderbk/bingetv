import 'package:flutter/material.dart';

const bingeYellow = Color(0xFFFFD600);
const bingePurple = Color(0xFF7C3AED);
const bingeDeepPurple = Color(0xFF4C1D95);
const bingeBackground = Color(0xFF08090C);
const bingeSurface = Color(0xFF111318);
const bingeRaised = Color(0xFF1A1D24);
const bingeGlassSurface = Color(0xCC171A22);
const bingeGlassBorder = Color(0x3DFFFFFF);
const bingeTextSecondary = Color(0xFFB8B3C9);
const bingeTextTertiary = Color(0xFF7C7790);
const bingeDanger = Color(0xFFFF5C6C);
const bingeDarkBg = bingeSurface;
const bingeFieldBg = bingeRaised;
const bingeDivider = Color(0xFF282C35);
const bingeCardWidth = 300.0;
const bingeCardHeight = 214.0;
const bingePagePadding = 64.0;

ThemeData buildBingeTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: bingeBackground,
    colorScheme: const ColorScheme.dark(
      primary: bingeYellow,
      secondary: bingePurple,
      surface: bingeBackground,
    ),
    dividerColor: bingeDivider,
    splashColor: bingeYellow.withValues(alpha: 0.12),
    highlightColor: bingeYellow.withValues(alpha: 0.08),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      fontFamily: 'Inter',
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bingeFieldBg,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: bingeDivider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: bingeYellow, width: 2),
      ),
    ),
  );
}
