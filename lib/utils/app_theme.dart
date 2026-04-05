// ============================================================
// app_theme.dart
// Tema Severu's Barbearia (dark-first).
// ============================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppTheme {
  // Tokens principais da marca.
  static const Color primaryColor = Color(0xFF010100); // background
  static const Color secondaryColor = Color(0xFF1A1600); // surfaceVariant
  static const Color cardDark = Color(0xFF1A1600); // surfaceVariant
  static const Color accentColor = Color(0xFFFBAB0C); // primary
  static const Color goldColor = Color(0xFFFFED63); // secondary
  static const Color cardBorderColor = Color(0xFF976800); // outline
  static const Color textPrimary = Color(0xFFEAEAE9); // onSurface
  static const Color textSecondary = Color(0xFF976800); // onSurfaceVariant
  static const Color errorColor = Color(0xFFCF6679);

  // Mantidos para compatibilidade com o restante do app.
  static const Color successColor = Color(0xFFFBAB0C);
  static const Color infoColor = Color(0xFFFFED63);
  static const Color warningColor = Color(0xFFFFED63);
  static const Color accentDark = Color(0xFF976800);
  static const Color infoDark = Color(0xFF976800);
  static const Color successDark = Color(0xFF976800);
  static const Color warningDark = Color(0xFF976800);
  static const Color purpleStart = Color(0xFF1A1600);
  static const Color purpleEnd = Color(0xFF1A1600);
  static const Color cyanColor = Color(0xFFFFED63);
  static const Color inputFill = Color(0xFF1A1600);
  static const Color lightBackground = Color(0xFF010100);
  static const Color lightCard = Color(0xFF1A1600);
  static const Color lightTextPrimary = Color(0xFFEAEAE9);
  static const Color lightTextSecondary = Color(0xFF976800);
  static const Color lightInputFill = Color(0xFF1A1600);
  static const Color lightInputBorder = Color(0xFF976800);
  static const Color lightDivider = Color(0xFF976800);
  static const Color silverColor = Color(0xFFEAEAE9);
  static const Color bronzeColor = Color(0xFF976800);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFBAB0C),
          onPrimary: Color(0xFF010100),
          secondary: Color(0xFFFFED63),
          onSecondary: Color(0xFF010100),
          secondaryContainer: Color(0xFF976800),
          onSecondaryContainer: Color(0xFFFFED63),
          surface: Color(0xFF010100),
          onSurface: Color(0xFFEAEAE9),
          surfaceVariant: Color(0xFF1A1600),
          onSurfaceVariant: Color(0xFF976800),
          outline: Color(0xFF976800),
          background: Color(0xFF010100),
          onBackground: Color(0xFFEAEAE9),
          error: Color(0xFFCF6679),
          onError: Color(0xFF010100),
        ),
        scaffoldBackgroundColor: const Color(0xFF010100),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF010100),
          foregroundColor: Color(0xFFFBAB0C),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFBAB0C),
            foregroundColor: const Color(0xFF010100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFBAB0C),
            side: const BorderSide(color: Color(0xFF976800), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFF976800), width: 0.5),
          ),
          elevation: 0,
        ),
        dividerColor: const Color(0xFF976800),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Color(0xFFFBAB0C),
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: Color(0xFFEAEAE9),
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(color: Color(0xFFEAEAE9)),
          bodyMedium: TextStyle(color: Color(0xFFEAEAE9)),
          bodySmall: TextStyle(color: Color(0xFF976800)),
          labelLarge: TextStyle(
            color: Color(0xFF010100),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // App dark-first: quando o modo light for selecionado, mantemos a paleta da marca.
  static ThemeData get lightTheme => darkTheme;
}
