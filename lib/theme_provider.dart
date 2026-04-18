import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppTheme { sovereignDark, royalLight, matrixGreen }

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.sovereignDark;

  AppTheme get currentTheme => _currentTheme;

  void setTheme(AppTheme theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppTheme.sovereignDark:
        return _sovereignDark();
      case AppTheme.royalLight:
        return _royalLight();
      case AppTheme.matrixGreen:
        return _matrixGreen();
    }
  }

  ThemeData _sovereignDark() {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF3B82F6),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardColor: const Color(0xFF1E293B),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF10B981),
        surface: Color(0xFF1E293B),
      ),
    );
  }

  ThemeData _royalLight() {
    return ThemeData.light().copyWith(
      primaryColor: const Color(0xFF6366F1),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF8B5CF6),
        surface: Colors.white,
      ),
    );
  }

  ThemeData _matrixGreen() {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF00FF41),
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF0D0D0D),
      textTheme: GoogleFonts.shareTechMonoTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00FF41),
        secondary: Color(0xFF008F11),
        surface: Color(0xFF0D0D0D),
      ),
    );
  }
}
