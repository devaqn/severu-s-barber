import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/cliente.dart';
import '../../services/atendimento_service.dart';
import '../../services/cliente_service.dart';
import '../../services/produto_service.dart';
import '../../services/servico_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final ServicoService _servicoService = ServicoService();
  final ProdutoService _produtoService = ProdutoService();
  final AtendimentoService _atendimentoService = AtendimentoService();
  final ClienteService _clienteService = ClienteService();

  late final TabController _tabController;

  List<Map<String, dynamic>> _servicosMaisRealizados = [];
  List<Map<String, dynamic>> _produtosMaisVendidos = [];
  List<Map<String, dynamic>> _horariosMaisLucrativos = [];
  List<Map<String, dynamic>> _clientesSumidos = [];

  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final results = await Future.wait([
        _servicoService.getMaisRealizados(limit: 8),
        _produtoService.getMaisVendidos(limit: 8),
        _atendimentoService.getMapaHorarios(),
        _clienteService.getClientesSumidos(),
      ]);

      if (!mounted) return;

      final mapa = (results[2] as List).cast<Map<String, dynamic>>();

      setState(() {
        _servicosMaisRealizados =
            (results[0] as List).cast<Map<String, dynamic>>();
        _produtosMaisVendidos =
            (results[1] as List).cast<Map<String, dynamic>>();
        _horariosMaisLucrativos = mapa
            .map(
              (m) => {
                'hora': m['hora'],
                'quantidade': m['total_atendimentos'] ?? 0,
                'faturamento': m['total_faturamento'] ?? 0,
              },
            )
            .toList(growable: false);
        _clientesSumidos = (results[3] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Falha ao carregar analytics: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedItem: AppDrawer.analytics),
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Serviços'),
            Tab(text: 'Produtos'),
            Tab(text: 'Horários'),
            Tab(text: 'Clientes'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? AppPageContainer(
                  child: AppErrorState(
                    title: 'Não foi possível carregar o analytics',
                    subtitle: _erro!,
                    onRetry: _carregar,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildServicosTab(),
                    _buildProdutosTab(),
                    _buildHorariosTab(),
                    _buildClientesTab(),
                  ],
                ),
    );
  }

  Widget _buildServicosTab() {
    if (_servicosMaisRealizados.isEmpty) {
      return const AppPageContainer(
        child: AppEmptyState(
          icon: Icons.design_services,
          title: 'Sem dados de serviços',
          subtitle: 'Finalize atendimentos para gerar esse painel.',
        ),
      );
    }

    final maxVendas = _servicosMaisRealizados
        .map((e) => (e['total_vendas'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return AppPageContainer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.design_services,
              title: 'Serviços Mais Realizados',
              subtitle: 'Volume e faturamento por serviço',
            ),
            const SizedBox(height: 12),
            if (maxVendas > 0) _buildServicosChart(maxVendas),
            const SizedBox(height: 12),
            ..._servicosMaisRealizados.map(
              (s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.content_cut,
                      color: AppTheme.accentColor),
                  title: Text(s['nome'] as String? ?? 'Serviço'),
                  subtitle: Text('${s['total_vendas']} realizações'),
                  trailing: Text(
                    AppFormatters.currency(
                      (s['faturamento_total'] as num?)?.toDouble() ?? 0,
                    ),
                    style: const TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicosChart(double maxVendas) {
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVendas * 1.25,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _servicosMaisRealizados.length) {
                    return const SizedBox.shrink();
                  }
                  final nome =
                      (_servicosMaisRealizados[i]['nome'] as String? ?? '')
                          .split(' ')
                          .first;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(nome, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: _servicosMaisRealizados.asMap().entries.map((entry) {
            final vendas =
                (entry.value['total_vendas'] as num?)?.toDouble() ?? 0;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: vendas,
                  color: AppTheme.accentColor,
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildProdutosTab() {
    if (_produtosMaisVendidos.isEmpty) {
      return const AppPageContainer(
        child: AppEmptyState(
          icon: Icons.inventory_2,
          title: 'Sem dados de produtos',
          subtitle: 'Registre vendas para acompanhar o desempenho do estoque.',
        ),
      );
    }

    return AppPageContainer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.shopping_bag,
              title: 'Produtos Mais Vendidos',
              subtitle: 'Ranking de itens vendidos e lucro estimado',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 42,
                  sectionsSpace: 2,
                  sections: _produtosMaisVendidos.asMap().entries.map((entry) {
                    final item = entry.value;
                    return PieChartSectionData(
                      value: (item['total_vendas'] as num?)?.toDouble() ?? 0,
                      title: '${item['total_vendas']}',
                      radius: 82,
                      color: _chartColors[entry.key % _chartColors.length],
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._produtosMaisVendidos.asMap().entries.map((entry) {
              final item = entry.value;
              final lucro = (item['lucro_total'] as num?)?.toDouble() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _chartColors[entry.key % _chartColors.length]
                            .withValues(alpha: 0.2),
                    child: Text(
                      '${entry.key + 1}º',
                      style: TextStyle(
                        color: _chartColors[entry.key % _chartColors.length],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(item['nome'] as String? ?? 'Produto'),
                  subtitle: Text('${item['total_vendas']} venda(s)'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.currency(
                          (item['faturamento_total'] as num?)?.toDouble() ?? 0,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Lucro: ${AppFormatters.currency(lucro)}',
                        style: TextStyle(
                          color: lucro >= 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHorariosTab() {
    if (_horariosMaisLucrativos.isEmpty) {
      return const AppPageContainer(
        child: AppEmptyState(
          icon: Icons.access_time,
          title: 'Sem dados de horários',
          subtitle:
              'Os horários mais lucrativos aparecerão após os atendimentos.',
        ),
      );
    }

    final ordenados = List<Map<String, dynamic>>.from(_horariosMaisLucrativos)
      ..sort((a, b) =>
          ((a['hora'] as int?) ?? 0).compareTo((b['hora'] as int?) ?? 0));
    final topHorario = ordenados.reduce(
      (a, b) => ((a['faturamento'] as num?)?.toDouble() ?? 0) >
              ((b['faturamento'] as num?)?.toDouble() ?? 0)
          ? a
          : b,
    );
    final maxFat = ordenados
        .map((e) => (e['faturamento'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return AppPageContainer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.query_stats,
              title: 'Horários Mais Lucrativos',
              subtitle: 'Descubra as faixas de maior faturamento',
            ),
            const SizedBox(height: 12),
            Card(
              color: AppTheme.accentColor.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.star, color: AppTheme.goldColor),
                title: const Text('Melhor faixa horária'),
                subtitle: Text(
                  '${topHorario['hora']}h - ${((topHorario['hora'] as int?) ?? 0) + 1}h',
                ),
                trailing: Text(
                  AppFormatters.currency(
                    (topHorario['faturamento'] as num?)?.toDouble() ?? 0,
                  ),
                  style: const TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (maxFat > 0)
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxFat * 1.25,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.textSecondary.withValues(alpha: 0.2),
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
                          getTitlesWidget: (v, _) => Text(
                            '${v.toInt()}h',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                    barGroups: ordenados.map((item) {
                      final hora = (item['hora'] as int?) ?? 0;
                      final fat =
                          (item['faturamento'] as num?)?.toDouble() ?? 0;
                      return BarChartGroupData(
                        x: hora,
                        barRods: [
                          BarChartRodData(
                            toY: fat,
                            width: 16,
                            color: hora == ((topHorario['hora'] as int?) ?? 0)
                                ? AppTheme.goldColor
                                : AppTheme.accentColor.withValues(alpha: 0.8),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ...ordenados.map(
              (h) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.access_time, color: AppTheme.infoColor),
                title: Text('${h['hora']}h - ${((h['hora'] as int?) ?? 0) + 1}h'),
                subtitle: Text('${h['quantidade']} atendimento(s)'),
                trailing: Text(
                  AppFormatters.currency(
                      (h['faturamento'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientesTab() {
    return AppPageContainer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.person_off,
              title: 'Clientes Sumidos',
              subtitle: 'Clientes frequentes que estão sem retornar',
            ),
            const SizedBox(height: 10),
            if (_clientesSumidos.isEmpty)
              const AppEmptyState(
                icon: Icons.people,
                title: 'Nenhum cliente em risco',
                subtitle: 'Todos os clientes frequentes estão em dia.',
              )
            else
              ..._clientesSumidos.map((item) {
                final cliente = item['cliente'] as Cliente;
                final diasSemVir = (item['diasSemVir'] as int?) ?? 0;
                final media = (item['mediaIntervalo'] as int?) ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x33FFC107),
                      child:
                          Icon(Icons.person_off, color: AppTheme.warningColor),
                    ),
                    title: Text(cliente.nome),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Costuma vir a cada $media dia(s).'),
                        Text(
                          'Está há $diasSemVir dia(s) sem aparecer.',
                          style: const TextStyle(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      AppFormatters.phone(cliente.telefone),
                      style: const TextStyle(fontSize: 11),
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
            const SizedBox(height: 20),
            const _SectionHeader(
              icon: Icons.calculate,
              title: 'Simulador de Preços',
              subtitle: 'Projete impacto de reajuste de serviços',
            ),
            const SizedBox(height: 10),
            const _SimuladorPreco(),
          ],
        ),
      ),
    );
  }

  static const List<Color> _chartColors = [
    AppTheme.accentColor,
    AppTheme.infoColor,
    AppTheme.goldColor,
    AppTheme.successColor,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimuladorPreco extends StatefulWidget {
  const _SimuladorPreco();

  @override
  State<_SimuladorPreco> createState() => _SimuladorPrecoState();
}

class _SimuladorPrecoState extends State<_SimuladorPreco> {
  final _precoAtualCtrl = TextEditingController(text: '35');
  final _novoPrecoCtrl = TextEditingController(text: '40');
  final _qtdCtrl = TextEditingController(text: '60');
  Map<String, double>? _resultado;

  @override
  void dispose() {
    _precoAtualCtrl.dispose();
    _novoPrecoCtrl.dispose();
    _qtdCtrl.dispose();
    super.dispose();
  }

  void _simular() {
    final precoAtual =
        double.tryParse(_precoAtualCtrl.text.replaceAll(',', '.'));
    final novoPreco = double.tryParse(_novoPrecoCtrl.text.replaceAll(',', '.'));
    final qtd = int.tryParse(_qtdCtrl.text);
    if (precoAtual == null || novoPreco == null || qtd == null) return;

    setState(() {
      _resultado = {
        'faturamentoAtual': precoAtual * qtd,
        'faturamentoNovo': novoPreco * qtd,
        'diferenca': (novoPreco - precoAtual) * qtd,
        'percentual':
            precoAtual > 0 ? (novoPreco - precoAtual) / precoAtual : 0,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _precoAtualCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Preço atual (R\$)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _novoPrecoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Novo preço (R\$)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Atendimentos/mês'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _simular,
                icon: const Icon(Icons.calculate),
                label: const Text('Simular'),
              ),
            ),
            if (_resultado != null) ...[
              const Divider(height: 24),
              _buildResult(
                'Faturamento atual',
                _resultado!['faturamentoAtual']!,
                AppTheme.textSecondary,
              ),
              _buildResult(
                'Novo faturamento',
                _resultado!['faturamentoNovo']!,
                AppTheme.successColor,
              ),
              _buildResult(
                'Diferença',
                _resultado!['diferenca']!,
                _resultado!['diferenca']! >= 0
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
              ),
              const SizedBox(height: 4),
              Text(
                'Variação: ${AppFormatters.percent(_resultado!['percentual']!)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _resultado!['diferenca']! >= 0
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResult(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            AppFormatters.currency(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
