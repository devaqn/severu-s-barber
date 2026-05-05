import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_theme.dart';

enum AppNoticeType { success, error, info }

class UiFeedback {
  static String friendlyError(Object? error, {required String fallback}) {
    final raw = (error ?? '').toString();
    final lower = raw.toLowerCase();

    if (lower.contains('cloud_firestore/failed-precondition') &&
        lower.contains('requires an index')) {
      return 'Estamos ajustando a lista. Tente novamente em alguns segundos.';
    }
    if (lower.contains('cloud_firestore/permission-denied') ||
        lower.contains('permission_denied') ||
        lower.contains('permission denied') ||
        lower.contains('permiss')) {
      return 'Seu acesso ainda nao esta liberado para essa acao. Saia e entre novamente; se continuar, fale com o administrador.';
    }
    if (lower.contains('unique constraint failed') ||
        lower.contains('sqlite_constraint_unique') ||
        lower.contains('duplicate')) {
      return 'Esse registro ja estava salvo neste aparelho. Atualizamos a lista para evitar duplicidade.';
    }
    if (lower.contains('network') ||
        lower.contains('unavailable') ||
        lower.contains('sem conexao')) {
      return 'Sem conexao no momento. Verifique a internet e tente novamente.';
    }
    if (raw.trim().isEmpty) return fallback;
    if (raw.length > 180 ||
        lower.contains('databaseexception') ||
        lower.contains('firebaseexception') ||
        lower.contains('http')) {
      return fallback;
    }
    return raw.replaceFirst('Exception: ', '');
  }

  static void showSnack(
    BuildContext context,
    String message, {
    AppNoticeType type = AppNoticeType.info,
  }) {
    final color = switch (type) {
      AppNoticeType.success => AppTheme.successColor,
      AppNoticeType.error => AppTheme.errorColor,
      AppNoticeType.info => AppTheme.infoColor,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }
}

class AppPageContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const AppPageContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.maxWidth = 1120,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final effectivePadding = width < 420
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
            : padding;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: effectivePadding,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 42),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const AppErrorState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.errorColor, size: 40),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
