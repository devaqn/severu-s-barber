// ============================================================
// app_theme.dart
// Tema Severu's Barbearia (dark-first, com suporte real claro/escuro).
// ============================================================
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppTheme {
  // Tokens principais da marca (PRD v3).
  static const Color primaryColor = Color(0xFF1A1A2E); // fundo principal
  static const Color secondaryColor = Color(0xFF24243A); // superfície
  static const Color cardDark = Color(0xFF2C2C44); // card
  static const Color accentColor = Color(0xFFB8860B); // dourado base
  static const Color goldColor = Color(0xFFD4AF37); // dourado destaque
  static const Color cardBorderColor = Color(0xFF8A6508); // borda dourada
  static const Color textPrimary = Color(0xFFFFFFFF); // texto principal
  static const Color textSecondary = Color(0xFFC9C9D6); // texto secundário
  static const Color errorColor = Color(0xFFC0392B);

  // Mantidos para compatibilidade com o restante do app.
  static const Color successColor = Color(0xFF2ECC71);
  static const Color infoColor = Color(0xFFB8860B);
  static const Color warningColor = Color(0xFFB8860B);
  static const Color accentDark = Color(0xFF8A6508);
  static const Color infoDark = Color(0xFF8A6508);
  static const Color successDark = Color(0xFF1F9D55);
  static const Color warningDark = Color(0xFF8A6508);
  static const Color purpleStart = Color(0xFF1A1A2E);
  static const Color purpleEnd = Color(0xFF24243A);
  static const Color cyanColor = Color(0xFFB8860B);
  static const Color inputFill = Color(0xFF2C2C44);
  static const Color lightBackground = Color(0xFFF7F3E9);
  static const Color lightCard = Color(0xFFFFFCF6);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF4F5566);
  static const Color lightInputFill = Color(0xFFFAF2E1);
  static const Color lightInputBorder = Color(0xFFC9A24A);
  static const Color lightDivider = Color(0xFFE7DCC3);
  static const Color silverColor = Color(0xFFE5E5EE);
  static const Color bronzeColor = Color(0xFFA67C38);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB8860B),
          onPrimary: Color(0xFF000000),
          secondary: Color(0xFFD4AF37),
          onSecondary: Color(0xFF000000),
          secondaryContainer: Color(0xFF8A6508),
          onSecondaryContainer: Color(0xFFFFFFFF),
          surface: Color(0xFF24243A),
          onSurface: Color(0xFFFFFFFF),
          surfaceVariant: Color(0xFF2C2C44),
          onSurfaceVariant: Color(0xFFC9C9D6),
          outline: Color(0xFF8A6508),
          background: Color(0xFF1A1A2E),
          onBackground: Color(0xFFFFFFFF),
          error: Color(0xFFC0392B),
          onError: Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB8860B),
          foregroundColor: Color(0xFF000000),
          iconTheme: IconThemeData(color: Color(0xFF000000)),
          actionsIconTheme: IconThemeData(color: Color(0xFF000000)),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB8860B),
            foregroundColor: const Color(0xFF000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD4AF37),
            side: const BorderSide(color: Color(0xFF8A6508), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF2C2C44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFF8A6508), width: 0.5),
          ),
          elevation: 0,
        ),
        dividerColor: const Color(0xFF8A6508),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF24243A),
          textStyle: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF24243A),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
          bodyMedium: TextStyle(color: Color(0xFFFFFFFF)),
          bodySmall: TextStyle(color: Color(0xFFC9C9D6)),
          labelLarge: TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFB8860B),
          onPrimary: Color(0xFF000000),
          secondary: Color(0xFF24243A),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFF3E8CF),
          onSecondaryContainer: Color(0xFF1A1A2E),
          surface: Color(0xFFFFFCF6),
          onSurface: Color(0xFF1A1A2E),
          surfaceVariant: Color(0xFFFAF2E1),
          onSurfaceVariant: Color(0xFF4F5566),
          outline: Color(0xFFC9A24A),
          outlineVariant: Color(0xFFE7DCC3),
          background: Color(0xFFF7F3E9),
          onBackground: Color(0xFF1A1A2E),
          error: Color(0xFFC0392B),
          onError: Color(0xFFFFFFFF),
          shadow: Color(0x14000000),
        ),
        scaffoldBackgroundColor: lightBackground,

        // ── AppBar ──────────────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB8860B),
          foregroundColor: Color(0xFF000000),
          iconTheme: IconThemeData(color: Color(0xFF000000)),
          actionsIconTheme: IconThemeData(color: Color(0xFF000000)),
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),

        // ── Ícones globais ───────────────────────────────────────────────
        iconTheme: const IconThemeData(color: lightTextPrimary),

        // ── Botões ───────────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB8860B),
            foregroundColor: const Color(0xFF000000),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB8860B),
            side: const BorderSide(color: Color(0xFFC9A24A), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFB8860B),
          ),
        ),

        // ── Cartões ──────────────────────────────────────────────────────
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFCF6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFFE7DCC3), width: 0.8),
          ),
          elevation: 1,
          shadowColor: Color(0x18B8860B),
          surfaceTintColor: Colors.transparent,
        ),

        // ── Divisor ──────────────────────────────────────────────────────
        dividerColor: const Color(0xFFE7DCC3),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE7DCC3),
          thickness: 1,
          space: 1,
        ),

        // ── Campos de texto ──────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightInputFill,
          labelStyle: const TextStyle(color: lightTextSecondary),
          hintStyle: const TextStyle(color: lightTextSecondary),
          prefixIconColor: lightTextSecondary,
          suffixIconColor: lightTextSecondary,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: lightInputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: accentColor, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: errorColor, width: 1.8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),

        // ── Switch / Checkbox / Radio ─────────────────────────────────────
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFB8860B);
            }
            return const Color(0xFF9E9E9E);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFB8860B).withOpacity(0.4);
            }
            return const Color(0xFFBDBDBD).withOpacity(0.4);
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFB8860B);
            }
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.black),
          side: const BorderSide(color: Color(0xFFC9A24A), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFB8860B);
            }
            return const Color(0xFF4F5566);
          }),
        ),

        // ── ListTile ──────────────────────────────────────────────────────
        listTileTheme: ListTileThemeData(
          tileColor: Colors.transparent,
          selectedTileColor: const Color(0xFFB8860B).withOpacity(0.1),
          selectedColor: const Color(0xFFB8860B),
          iconColor: lightTextSecondary,
          textColor: lightTextPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),

        // ── Drawer ───────────────────────────────────────────────────────
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFFFFCF6),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
        ),

        // ── SegmentedButton ───────────────────────────────────────────────
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFB8860B);
              }
              return const Color(0xFFFFFCF6);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.black;
              }
              return lightTextPrimary;
            }),
          ),
        ),

        // ── Dialog ───────────────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFCF6),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: const TextStyle(
            color: Color(0xFF4F5566),
            fontSize: 14,
          ),
        ),

        // ── BottomSheet ───────────────────────────────────────────────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFFFFCF6),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          showDragHandle: true,
          dragHandleColor: Color(0xFFC9A24A),
        ),

        // ── SnackBar ──────────────────────────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1A1A2E),
          contentTextStyle: const TextStyle(color: Color(0xFFFFFFFF)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),

        // ── TabBar ────────────────────────────────────────────────────────
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFFB8860B),
          unselectedLabelColor: Color(0xFF4F5566),
          indicatorColor: Color(0xFFB8860B),
          indicatorSize: TabBarIndicatorSize.tab,
        ),

        // ── ProgressIndicator ─────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFB8860B),
        ),

        // ── Texto ─────────────────────────────────────────────────────────
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E)),
          bodyMedium: TextStyle(color: Color(0xFF4F5566)),
          bodySmall: TextStyle(color: Color(0xFF4F5566)),
          labelLarge: TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
