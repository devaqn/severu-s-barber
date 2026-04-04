// ============================================================
// app_theme.dart
// Define o tema visual do aplicativo (cores, fontes, estilos).
// Suporta modo claro e modo escuro.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta principal definida para identidade SaaS premium.
  static const Color primaryColor = Color(0xFF1A1A2E);
  static const Color secondaryColor = Color(0xFF16213E);
  static const Color accentColor = Color(0xFFE94560);
  static const Color goldColor = Color(0xFFF5A623);
  static const Color successColor = Color(0xFF00B894);
  static const Color infoColor = Color(0xFF0984E3);
  static const Color warningColor = Color(0xFFFDCB6E);
  static const Color errorColor = Color(0xFFD63031);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A3BD);

  // Cores auxiliares para gradientes e variacoes visuais consistentes.
  static const Color accentDark = Color(0xFFC0392B);
  static const Color infoDark = Color(0xFF0652DD);
  static const Color successDark = Color(0xFF00695C);
  static const Color warningDark = Color(0xFFE17055);
  static const Color purpleStart = Color(0xFF6C5CE7);
  static const Color purpleEnd = Color(0xFF4834D4);
  static const Color cyanColor = Color(0xFF00CEC9);
  static const Color inputFill = Color(0xFF0F3460);
  static const Color lightBackground = Color(0xFFF8F9FF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6E7191);
  static const Color lightInputFill = Color(0xFFF1F3FF);
  static const Color lightInputBorder = Color(0xFFDCE0FF);
  static const Color lightDivider = Color(0xFFE5E8FF);
  static const Color silverColor = Color(0xFFC0C0C0);
  static const Color bronzeColor = Color(0xFFCD7F32);

  // ThemeData escuro principal do aplicativo.
  static ThemeData get darkTheme {
    final baseText = GoogleFonts.interTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textSecondary),
      ),
    );

    final textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.poppins(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.poppins(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.poppins(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryColor,
      cardColor: secondaryColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: goldColor,
        surface: secondaryColor,
        error: errorColor,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: secondaryColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: secondaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: inputFill),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: textPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: secondaryColor,
        selectedItemColor: accentColor,
        unselectedItemColor: textSecondary,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputFill,
        selectedColor: accentColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        labelStyle: const TextStyle(color: textPrimary),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: accentColor,
        labelColor: accentColor,
        unselectedLabelColor: textSecondary,
      ),
      dividerTheme: const DividerThemeData(color: inputFill),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: secondaryColor,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ThemeData claro equivalente com paleta adaptada ao fundo light.
  static ThemeData get lightTheme {
    final baseText = GoogleFonts.interTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextSecondary),
        bodySmall: TextStyle(color: lightTextSecondary),
      ),
    );

    final textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.poppins(
        color: lightTextPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.poppins(
        color: lightTextPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.poppins(
        color: lightTextPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCard,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        secondary: goldColor,
        surface: lightCard,
        error: errorColor,
        onPrimary: textPrimary,
        onSecondary: lightTextPrimary,
        onSurface: lightTextPrimary,
        onError: textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightInputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
        labelStyle: const TextStyle(color: lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: textPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCard,
        selectedItemColor: accentColor,
        unselectedItemColor: lightTextSecondary,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightInputFill,
        selectedColor: accentColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        labelStyle: const TextStyle(color: lightTextPrimary),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: accentColor,
        labelColor: accentColor,
        unselectedLabelColor: lightTextSecondary,
      ),
      dividerTheme: const DividerThemeData(color: lightDivider),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightCard,
        contentTextStyle: GoogleFonts.inter(color: lightTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
