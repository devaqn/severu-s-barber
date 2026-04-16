// ============================================================
// stat_card.dart
// Card reutilizavel para exibir estatisticas no dashboard.
// Suporta icone, cor/gradiente, titulo, valor e subtitulo.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<Color>? gradient;
  final String? subtitle;
  /// Se verdadeiro, ocupa toda a largura disponivel.
  final bool isFullWidth;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.gradient,
    this.subtitle,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    // Cor base usada para sombra quando o card usa gradiente.
    final primaryShadowColor = gradient != null && gradient!.isNotEmpty
        ? gradient!.first
        : color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient!,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryShadowColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isFullWidth
          ? Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 12),
                Expanded(child: _buildContent()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(),
                const SizedBox(height: 12),
                _buildContent(),
              ],
            ),
    );
  }

  // Monta o icone com destaque branco no topo do card.
  Widget _buildIcon() {
    return Icon(
      icon,
      color: AppTheme.textPrimary.withValues(alpha: 0.95),
      size: 26,
    );
  }

  // Monta bloco textual principal do card de estatistica.
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textPrimary.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

