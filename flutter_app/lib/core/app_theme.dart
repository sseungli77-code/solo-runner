
import 'package:flutter/material.dart';

class AppTheme {
  static const Color neonCyan = Color(0xFF00FFF0);
  static const Color neonPink = Color(0xFFFF0055);
  static const Color background = Color(0xFF090910);
  static const Color surface = Color(0xFF1E1E2C);
  
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonPink,
        surface: surface,
        background: background,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }
}
