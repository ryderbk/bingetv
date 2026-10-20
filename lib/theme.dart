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
const bingeSpace1 = 4.0;
const bingeSpace2 = 8.0;
const bingeSpace3 = 12.0;
const bingeSpace4 = 16.0;
const bingeSpace5 = 24.0;
const bingeSpace6 = 32.0;
const bingeSpace7 = 48.0;
const bingeRadiusSmall = 8.0;
const bingeRadiusMedium = 12.0;
const bingeRadiusLarge = 20.0;
const bingePagePadding = 64.0;

EdgeInsets bingePageInsets(double width, {double vertical = 32}) =>
    EdgeInsets.symmetric(
      horizontal: (width * 0.055).clamp(20.0, bingePagePadding).toDouble(),
      vertical: vertical,
    );

const bingeScreenTitle = TextStyle(
  color: bingeYellow,
  fontSize: 36,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.6,
);
const bingeSectionTitle = TextStyle(
  color: Colors.white,
  fontSize: 22,
  fontWeight: FontWeight.w700,
);
const bingeBodyText = TextStyle(color: Colors.white, fontSize: 18);
const bingeSecondaryText = TextStyle(
  color: bingeTextSecondary,
  fontSize: 16,
);
const bingeButtonText = TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w600,
);

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
      labelStyle: const TextStyle(color: bingeTextSecondary, fontSize: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(bingeRadiusMedium),
        borderSide: const BorderSide(color: bingeDivider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(bingeRadiusMedium),
        borderSide: const BorderSide(color: bingeYellow, width: 2),
      ),
    ),
  );
}
