// ============================================================
// ranking_screen.dart
// Ranking dos clientes que mais gastaram na barbearia.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import '../../utils/formatters.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_drawer.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final ClienteService _service = ClienteService();
  List<Cliente> _ranking = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final ranking = await _service.getRanking(limit: 20);
    if (mounted) {
      setState(() {
        _ranking = ranking;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedItem: AppDrawer.ranking),
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Ranking de Clientes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ranking.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum dado disponivel',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildPodio(),
                    const SizedBox(height: 16),
                    ..._buildListaRestante(),
                  ],
                ),
    );
  }

  Widget _buildPodio() {
    final top1 = _ranking.isNotEmpty ? _ranking[0] : null;
    final top2 = _ranking.length > 1 ? _ranking[1] : null;
    final top3 = _ranking.length > 2 ? _ranking[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _podioItem(
              cliente: top2,
              posicao: 2,
              height: 95,
              colors: const [AppTheme.silverColor, AppTheme.textSecondary],
            ),
          ),
          Expanded(
            child: _podioItem(
              cliente: top1,
              posicao: 1,
              height: 130,
              colors: const [AppTheme.goldColor, AppTheme.warningDark],
            ),
          ),
          Expanded(
            child: _podioItem(
              cliente: top3,
              posicao: 3,
              height: 82,
              colors: const [AppTheme.bronzeColor, AppTheme.warningDark],
            ),
          ),
        ],
      ),
    );
  }

  Widget _podioItem({
    required Cliente? cliente,
    required int posicao,
    required double height,
    required List<Color> colors,
  }) {
    if (cliente == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colors.first.withValues(alpha: 0.2),
          child: Text(
            cliente.nome.isNotEmpty ? cliente.nome[0].toUpperCase() : 'C',
            style: GoogleFonts.poppins(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '$posicao',
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cliente.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Text(
          AppFormatters.currency(cliente.totalGasto),
          style: GoogleFonts.inter(
            color: AppTheme.successColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildListaRestante() {
    if (_ranking.length <= 3) {
      return [
        Text(
          'Sem mais clientes no ranking.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
      ];
    }

    return _ranking.sublist(3).asMap().entries.map((entry) {
      final pos = entry.key + 4;
      final c = entry.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$pos',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                c.nome,
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              AppFormatters.currency(c.totalGasto),
              style: GoogleFonts.poppins(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

