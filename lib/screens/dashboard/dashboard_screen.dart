// ============================================================
// dashboard_screen.dart
// Tela principal com consolidacao de indicadores da barbearia.
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart' show themeModeNotifier;
import '../../models/agendamento.dart';
import '../../models/cliente.dart';
import '../../services/dashboard_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/stat_card.dart';
import '../agenda/agenda_screen.dart';
import '../atendimentos/novo_atendimento_screen.dart';
import '../clientes/cliente_form_screen.dart';
import '../ranking/ranking_screen.dart';

/// Tela principal que exibe resumo, grafico e atalhos operacionais.
class DashboardScreen extends StatefulWidget {
  /// Construtor padrao da dashboard.
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Estado da dashboard com carregamento assincrono de dados consolidados.
class _DashboardScreenState extends State<DashboardScreen> {
  // Servico agregador de dados da tela principal.
  final DashboardService _service = DashboardService();

  // Future cacheado para evitar recarregar em todo rebuild.
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    // Dispara carga inicial da dashboard.
    _future = _service.getDadosDashboard();
  }

  /// Recarrega os dados manualmente e atualiza a Future observada.
  Future<void> _recarregar() async {
    setState(() {
      _future = _service.getDadosDashboard();
    });
  }

  /// Retorna somente agendamentos do dia corrente para a secao dedicada.
  List<Agendamento> _agendamentosHoje(List<Agendamento> ags) {
    final now = DateTime.now();
    return ags
        .where((a) =>
            a.dataHora.year == now.year &&
            a.dataHora.month == now.month &&
            a.dataHora.day == now.day)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Estrutura principal com Drawer e conteudo rolavel.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.secondaryColor.withValues(alpha: 0.95),
                AppTheme.primaryColor.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.content_cut, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Severus Barber',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Gestao Profissional',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Alterna tema global claro/escuro.
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (ctx, mode, _) {
              return IconButton(
                tooltip: 'Alternar tema',
                onPressed: () {
                  themeModeNotifier.value =
                      mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                },
                icon: Icon(
                  mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                  color: AppTheme.textPrimary,
                ),
              );
            },
          ),
          IconButton(
            onPressed: _recarregar,
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.dashboard),
      floatingActionButton: ExpandableFab(
        mainColor: AppTheme.accentColor,
        shadowColor: AppTheme.accentColor.withValues(alpha: 0.4),
        actions: [
          ExpandableFabAction(
            label: 'Novo Atendimento',
            color: AppTheme.accentColor,
            icon: Icons.content_cut,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NovoAtendimentoScreen()),
              );
              await _recarregar();
            },
          ),
          ExpandableFabAction(
            label: 'Novo Agendamento',
            color: AppTheme.infoColor,
            icon: Icons.event_available,
            onPressed: () => Navigator.pushNamed(context, '/agenda'),
          ),
          ExpandableFabAction(
            label: 'Novo Cliente',
            color: AppTheme.successColor,
            icon: Icons.person_add,
            onPressed: () async {
              final cliente = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClienteFormScreen()),
              );
              if (cliente != null) {
                await _recarregar();
              }
            },
          ),
          ExpandableFabAction(
            label: 'Nova Despesa',
            color: AppTheme.errorColor,
            icon: Icons.money_off,
            onPressed: () => Navigator.pushNamed(context, '/financeiro'),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          // Estado de carregamento inicial da tela.
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // Estado de erro na carga consolidada.
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Erro ao carregar dashboard',
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          // Dados agregados retornados pelo service.
          final data = snapshot.data!;
          final agendamentos =
              (data['proximosAgendamentos'] as List).cast<Agendamento>();
          final topClientes = (data['topClientes'] as List).cast<Cliente>();
          final faturamentoPorDia =
              (data['faturamentoPorDia'] as List).cast<Map<String, dynamic>>();
          final estoqueBaixo = (data['produtosEstoqueBaixo'] as List).length;
          final agsHoje = _agendamentosHoje(agendamentos);

          // Conteudo principal da dashboard.
          return RefreshIndicator(
            onRefresh: _recarregar,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBannerLogo(),
                  const SizedBox(height: 16),
                  _buildResumoCards(data, estoqueBaixo),
                  const SizedBox(height: 20),
                  _buildGraficoFaturamento(faturamentoPorDia),
                  const SizedBox(height: 20),
                  _buildAgendamentosHoje(agsHoje),
                  const SizedBox(height: 20),
                  _buildTopClientes(topClientes),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Renderiza o logo principal da barbearia no topo da tela inicial.
  Widget _buildBannerLogo() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFF101010),
            child: Image.asset(
              'assets/images/severusbanner.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Logo nao encontrado',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Monta os cards de indicadores em pares horizontais.
  Widget _buildResumoCards(Map<String, dynamic> data, int estoqueBaixo) {
    // Conversoes para valores numericos usados nos cards.
    final fatHoje = (data['faturamentoDia'] as num).toDouble();
    final fatSemana = (data['faturamentoSemana'] as num).toDouble();
    final fatMes = (data['faturamentoMes'] as num).toDouble();
    final lucroMes = (data['lucroEstimado'] as num).toDouble();
    final atendHoje = data['atendimentosDia'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo Financeiro',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _cardPair(
          StatCard(
            title: 'Faturamento Hoje',
            value: AppFormatters.currency(fatHoje),
            icon: Icons.today,
            color: AppTheme.infoColor,
            gradient: const [AppTheme.infoColor, AppTheme.infoDark],
          ),
          StatCard(
            title: 'Faturamento Semana',
            value: AppFormatters.currency(fatSemana),
            icon: Icons.date_range,
            color: AppTheme.accentColor,
            gradient: const [AppTheme.accentColor, AppTheme.accentDark],
          ),
        ),
        const SizedBox(height: 10),
        _cardPair(
          StatCard(
            title: 'Faturamento Mes',
            value: AppFormatters.currency(fatMes),
            icon: Icons.calendar_month,
            color: AppTheme.successColor,
            gradient: const [AppTheme.successColor, AppTheme.successDark],
          ),
          StatCard(
            title: 'Atendimentos',
            value: '$atendHoje',
            icon: Icons.content_cut,
            color: AppTheme.purpleStart,
            gradient: const [AppTheme.purpleStart, AppTheme.purpleEnd],
          ),
        ),
        const SizedBox(height: 10),
        _cardPair(
          StatCard(
            title: 'Lucro Estimado',
            value: AppFormatters.currency(lucroMes),
            icon: Icons.trending_up,
            color: lucroMes >= 0 ? AppTheme.successColor : AppTheme.errorColor,
            gradient: lucroMes >= 0
                ? const [AppTheme.successColor, AppTheme.successDark]
                : const [AppTheme.errorColor, AppTheme.accentDark],
          ),
          StatCard(
            title: 'Estoque Baixo',
            value: '$estoqueBaixo item(ns)',
            icon: Icons.warning_amber_rounded,
            color:
                estoqueBaixo > 0 ? AppTheme.errorColor : AppTheme.textSecondary,
            gradient: estoqueBaixo > 0
                ? const [AppTheme.errorColor, AppTheme.accentDark]
                : const [AppTheme.textSecondary, AppTheme.secondaryColor],
          ),
        ),
      ],
    );
  }

  /// Organiza dois cards lado a lado com espacamento padrao.
  Widget _cardPair(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  /// Renderiza o grafico de linha para faturamento dos ultimos 30 dias.
  Widget _buildGraficoFaturamento(List<Map<String, dynamic>> pontos) {
    // Organiza pontos em ordem cronologica para o LineChart.
    final data = List<Map<String, dynamic>>.from(pontos)
      ..sort((a, b) => (a['dia'] as String).compareTo(b['dia'] as String));

    // Converte o resultado SQL em coordenadas de grafico.
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      final y = (data[i]['total'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), y));
    }

    // Calcula teto dinamico do eixo y.
    final maxY = spots.isEmpty
        ? 10.0
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.infoColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Faturamento',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '30 dias',
                  style: GoogleFonts.inter(
                    color: AppTheme.infoColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: spots.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.insert_chart_outlined,
                          size: 54,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum atendimento ainda',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Registre seu primeiro atendimento',
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                          color: AppTheme.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
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
                                  color: AppTheme.textSecondary,
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
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.infoColor, AppTheme.accentColor],
                          ),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.infoColor.withValues(alpha: 0.35),
                                AppTheme.accentColor.withValues(alpha: 0.05),
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

  /// Renderiza secao de agendamentos do dia com CTA para agenda completa.
  Widget _buildAgendamentosHoje(List<Agendamento> agendamentosHoje) {
    final agora = AppFormatters.time(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: AppTheme.infoColor),
              const SizedBox(width: 8),
              Text(
                'Hoje',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                agora,
                style: GoogleFonts.inter(color: AppTheme.textSecondary),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgendaScreen()),
                  );
                },
                child: const Text('Ver Agenda'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (agendamentosHoje.isEmpty)
            SizedBox(
              height: 90,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_available,
                        color: AppTheme.textSecondary),
                    const SizedBox(height: 6),
                    Text(
                      'Agenda limpa para hoje',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...agendamentosHoje.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppTheme.accentColor.withValues(alpha: 0.2),
                      child: Text(
                        a.clienteNome.isNotEmpty
                            ? a.clienteNome[0].toUpperCase()
                            : 'C',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.clienteNome,
                            style: GoogleFonts.poppins(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            a.servicoNome,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppFormatters.time(a.dataHora),
                        style: GoogleFonts.inter(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Renderiza secao de top clientes por valor gasto com atalho para ranking.
  Widget _buildTopClientes(List<Cliente> clientes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
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
                'Top Clientes',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RankingScreen()),
                  );
                },
                child: const Text('Ver Ranking'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (clientes.isEmpty)
            Text(
              'Nenhum cliente com historico ainda',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            )
          else
            ...clientes.take(5).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              Color posColor = AppTheme.textSecondary;
              if (i == 0) posColor = AppTheme.goldColor;
              if (i == 1) posColor = AppTheme.silverColor;
              if (i == 2) posColor = AppTheme.bronzeColor;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${i + 1}o',
                        style: GoogleFonts.poppins(
                          color: posColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: posColor.withValues(alpha: 0.2),
                      child: Icon(Icons.person, color: posColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.nome,
                        style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.currency(c.totalGasto),
                          style: GoogleFonts.poppins(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${c.pontosFidelidade} pts',
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
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
}

/// Modelo de acao filho do FAB expansivel.
class ExpandableFabAction {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  const ExpandableFabAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });
}

/// FAB expansivel customizado sem dependencias externas.
class ExpandableFab extends StatefulWidget {
  final List<ExpandableFabAction> actions;
  final Color mainColor;
  final Color shadowColor;

  const ExpandableFab({
    super.key,
    required this.actions,
    required this.mainColor,
    required this.shadowColor,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...widget.actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _open ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              offset: _open ? Offset.zero : const Offset(0, 0.2),
              child: IgnorePointer(
                ignoring: !_open,
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: index == widget.actions.length - 1 ? 10 : 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          action.label,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        heroTag: 'fab_action_$index',
                        backgroundColor: action.color,
                        onPressed: () {
                          setState(() => _open = false);
                          action.onPressed();
                        },
                        child: Icon(action.icon, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        FloatingActionButton(
          heroTag: 'fab_main_dashboard',
          backgroundColor: widget.mainColor,
          onPressed: () => setState(() => _open = !_open),
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: Icon(_open ? Icons.close : Icons.add,
                color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
