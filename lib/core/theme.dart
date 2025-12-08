import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B1121), // Deep Void Navy
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4F46E5), // Indigo
      secondary: Color(0xFF00FFFF), // Cyan (used heavily in gameplay)
      tertiary: Color(0xFFEC4899), // Magenta
      surface: Color(0xFF1E293B), // Slate 800 (fallback)
      error: Color(0xFFEF4444),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.white,
    ),
    textTheme: GoogleFonts.spaceGroteskTextTheme(
      ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
  );
  // Gradients removed as per user request
}
