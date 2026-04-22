// ============================================================
// admin_dashboard_screen.dart
// Dashboard administrativo: visão total da barbearia,
// ranking de barbeiros, faturamento e comandas abertas.
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../models/cliente.dart';
import '../../main.dart' show themeModeNotifier;
import '../../services/cliente_service.dart';
import '../../services/comanda_service.dart';
import '../../services/dashboard_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/ui_helpers.dart';
import '../comanda/comandas_screen.dart';

/// Dashboard do administrador com visão completa da barbearia.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ComandaService _comandaService = ComandaService();
  final ClienteService _clienteService = ClienteService();
  static const Color _expenseOrange = Color(0xFFE67E22);
  static const Color _expenseOrangeDark = Color(0xFFD35400);
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregarDados();
  }

  Future<void> _recarregar() async {
    setState(() => _future = _carregarDados());
  }

  Future<Map<String, dynamic>> _carregarDados() async {
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);

    final results = await Future.wait([
      _dashboardService.getDadosDashboard(),
      _comandaService.getRankingBarbeiros(inicioMes, agora),
      _comandaService.getCountComandasAbertas(),
      _clienteService.aniversariantesHoje(),
    ]);

    return {
      ...results[0] as Map<String, dynamic>,
      'rankingBarbeiros': results[1],
      'comandasAbertas': results[2],
      'aniversariantesHoje': results[3],
    };
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final cardSurface = isDark ? AppTheme.secondaryColor : AppTheme.lightCard;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accentColor, AppTheme.accentDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Severus Barber',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Admin: ${ctrl.usuarioNome}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: themeModeNotifier,
            builder: (ctx, mode, _) => IconButton(
              onPressed: () {
                themeModeNotifier.value =
                    mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
              icon: Icon(
                mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _recarregar,
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.dashboard),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AppPageContainer(
              child: AppErrorState(
                title: 'Falha ao carregar o dashboard',
                subtitle: 'Verifique a conexão e tente novamente.',
                onRetry: _recarregar,
              ),
            );
          }

          final data = snapshot.data!;
          final fatHoje = (data['faturamentoDia'] as num).toDouble();
          final fatMes = (data['faturamentoMes'] as num).toDouble();
          final lucro = (data['lucroEstimado'] as num).toDouble();
          final despesas = (data['despesasMes'] as num).toDouble();
          final atendHoje = data['atendimentosDia'] as int;
          final valorEstoque = (data['valorEstoque'] as num).toDouble();
          final estoqueBaixo = (data['produtosEstoqueBaixo'] as List).length;
          final faturamentoPorDia =
              (data['faturamentoPorDia'] as List).cast<Map<String, dynamic>>();
          final rankingBarbeiros =
              (data['rankingBarbeiros'] as List).cast<Map<String, dynamic>>();
          final comandasAbertas = data['comandasAbertas'] as int;
          final aniversariantesHoje =
              (data['aniversariantesHoje'] as List).cast<Cliente>();

          return AppPageContainer(
            child: RefreshIndicator(
              onRefresh: _recarregar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (aniversariantesHoje.isNotEmpty)
                      _buildBannerAniversariantes(aniversariantesHoje),
                    if (aniversariantesHoje.isNotEmpty)
                      const SizedBox(height: 12),
                    // Alerta de comandas abertas
                    if (comandasAbertas > 0)
                      _buildAlertaComandasAbertas(comandasAbertas),
                    const SizedBox(height: 12),

                    // Cards financeiros
                    _buildSectionTitle('Resumo Financeiro'),
                    const SizedBox(height: 10),
                    _buildMetricaDestaque(
                      titulo: 'Faturado Hoje',
                      valor: AppFormatters.currency(fatHoje),
                      subtitulo:
                          'Atualizado em ${AppFormatters.time(DateTime.now())}',
                      icone: Icons.today,
                    ),
                    const SizedBox(height: 10),
                    _buildCardPair(
                      StatCard(
                        title: 'Faturado no Mês',
                        value: AppFormatters.currency(fatMes),
                        icon: Icons.calendar_month,
                        color: AppTheme.accentColor,
                        gradient: const [
                          AppTheme.accentColor,
                          AppTheme.accentDark
                        ],
                      ),
                      StatCard(
                        title: 'Atendimentos',
                        value: '$atendHoje',
                        icon: Icons.content_cut,
                        color: AppTheme.textPrimary,
                        gradient: const [
                          AppTheme.purpleStart,
                          AppTheme.purpleEnd
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatCard(
                      title: 'Lucro Estimado',
                      value: AppFormatters.currency(lucro),
                      icon: Icons.trending_up,
                      isFullWidth: true,
                      color: lucro >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      gradient: lucro >= 0
                          ? const [AppTheme.successColor, AppTheme.successDark]
                          : const [AppTheme.errorColor, AppTheme.accentDark],
                    ),
                    const SizedBox(height: 10),
                    _buildDespesasMesCard(despesas),
                    const SizedBox(height: 10),
                    _buildCardPair(
                      StatCard(
                        title: 'Estoque Baixo',
                        value: '$estoqueBaixo item(ns)',
                        icon: Icons.warning_amber_rounded,
                        color: estoqueBaixo > 0
                            ? AppTheme.errorColor
                            : (isDark
                                ? AppTheme.textSecondary
                                : AppTheme.lightTextPrimary),
                        gradient: estoqueBaixo > 0
                            ? const [AppTheme.errorColor, AppTheme.accentDark]
                            : (isDark
                                ? const [
                                    AppTheme.textSecondary,
                                    AppTheme.secondaryColor,
                                  ]
                                : const [
                                    Color(0xFFDADDE8),
                                    Color(0xFFBEC4D7),
                                  ]),
                      ),
                      StatCard(
                        title: 'Comandas Abertas',
                        value: '$comandasAbertas',
                        icon: Icons.receipt_long,
                        color: AppTheme.accentColor,
                        gradient: const [
                          AppTheme.accentColor,
                          AppTheme.accentDark,
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Gráfico de faturamento
                    _buildGrafico(faturamentoPorDia),
                    const SizedBox(height: 20),

                    // Ranking de barbeiros
                    _buildRankingBarbeiros(rankingBarbeiros),
                    const SizedBox(height: 20),

                    // Valor do estoque
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2,
                              color: AppTheme.goldColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Valor Total em Estoque',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                  ),
                                ),
                                Text(
                                  AppFormatters.currency(valorEstoque),
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.goldColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertaComandasAbertas(int count) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ComandasScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.warningColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppTheme.warningColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count comanda(s) em aberto — Toque para ver',
                style: GoogleFonts.inter(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: AppTheme.warningColor, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildMetricaDestaque({
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentColor, AppTheme.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitulo,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDespesasMesCard(double despesas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_expenseOrange, _expenseOrangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _expenseOrange.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.money_off, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Despesas do Mês',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.currency(despesas),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Saídas e custos acumulados no período',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerAniversariantes(List<Cliente> clientes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final nomes = clientes.map((c) => c.nome).join(', ');
    final telefones = clientes
        .map((c) =>
            '${c.nome.split(' ').first}: ${AppFormatters.phone(c.telefone)}')
        .join('  •  ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake, color: Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              Text(
                'Aniversariantes de Hoje',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nomes,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            telefones,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPair(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: [
              left,
              const SizedBox(height: 10),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildRankingBarbeiros(List<Map<String, dynamic>> ranking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.secondaryColor : AppTheme.lightCard;
    final rowBg = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.4)
        : AppTheme.lightInputFill;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.goldColor),
              const SizedBox(width: 8),
              Text(
                'Ranking de Barbeiros',
                style: GoogleFonts.poppins(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ranking.isEmpty)
            Text(
              'Nenhuma comanda registrada ainda',
              style: GoogleFonts.inter(color: textSecondary),
            )
          else
            ...ranking.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final colors = [
                AppTheme.goldColor,
                AppTheme.silverColor,
                AppTheme.bronzeColor,
              ];
              final posColor = i < 3 ? colors[i] : textSecondary;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rowBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}º',
                        style: GoogleFonts.poppins(
                          color: posColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['barbeiro_nome'] as String? ?? 'Barbeiro',
                            style: GoogleFonts.poppins(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${r['total_comandas']} comanda(s)',
                            style: GoogleFonts.inter(
                                color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.currency(
                              (r['faturamento'] as num?)?.toDouble() ?? 0),
                          style: GoogleFonts.poppins(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Comissão: ${AppFormatters.currency((r['comissao'] as num?)?.toDouble() ?? 0)}',
                          style: GoogleFonts.inter(
                              color: AppTheme.goldColor, fontSize: 11),
                        ),
                        Text(
                          '% Config.: ${((r['comissao_percentual'] as num?)?.toDouble() ?? 50).toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGrafico(List<Map<String, dynamic>> pontos) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.secondaryColor : AppTheme.lightCard;

    final data = List<Map<String, dynamic>>.from(pontos)
      ..sort((a, b) => (a['dia'] as String).compareTo(b['dia'] as String));

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(
          FlSpot(i.toDouble(), (data[i]['total'] as num?)?.toDouble() ?? 0));
    }

    final maxY = spots.isEmpty
        ? 10.0
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Faturamento (30 dias)',
                style: GoogleFonts.poppins(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'Sem dados de faturamento',
                      style: GoogleFonts.inter(color: textSecondary),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (spots.length / 5).clamp(1, 8).toDouble(),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= data.length) {
                                return const SizedBox.shrink();
                              }
                              final dt =
                                  DateTime.tryParse(data[idx]['dia'] as String);
                              if (dt == null) return const SizedBox.shrink();
                              return Text(
                                '${dt.day}/${dt.month}',
                                style: GoogleFonts.inter(
                                  color: textSecondary,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          gradient: const LinearGradient(
                            colors: [AppTheme.accentColor, AppTheme.goldColor],
                          ),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentColor.withValues(alpha: 0.3),
                                AppTheme.goldColor.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                          spots: spots,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
