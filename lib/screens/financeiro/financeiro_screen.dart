// ============================================================
// financeiro_screen.dart
// Painel financeiro com resumo, despesas e simulador de lucro.
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/despesa.dart';
import '../../services/atendimento_service.dart';
import '../../services/financeiro_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';

/// Tela financeira com tres abas: resumo, despesas e simulador.
class FinanceiroScreen extends StatefulWidget {
  /// Construtor padrao da tela financeira.
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

/// Estado da tela com dados financeiros e filtros de periodo.
class _FinanceiroScreenState extends State<FinanceiroScreen>
    with SingleTickerProviderStateMixin {
  // Services de financeiro e atendimentos para consolidacao de dados.
  final FinanceiroService _service = FinanceiroService();
  final AtendimentoService _atendimentoService = AtendimentoService();

  // Controlador de abas da tela financeira.
  late TabController _tabController;

  // Estado de carregamento global da tela.
  bool _loading = true;

  // Intervalo ativo para resumo financeiro.
  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();

  // Resumo consolidado por periodo.
  Map<String, double> _resumo = {'faturamento': 0, 'despesas': 0, 'lucro': 0};

  // Dados semanais para grafico de barras.
  List<Map<String, double>> _semanas = [];

  // Lista de despesas da aba de despesas.
  List<Despesa> _despesas = [];

  // Filtro de categoria aplicado na aba de despesas.
  String _filtroCategoria = 'Todas';

  // Controllers da aba simulador de lucro.
  final TextEditingController _precoAtualCtrl = TextEditingController(text: '35');
  final TextEditingController _novoPrecoCtrl = TextEditingController(text: '40');
  final TextEditingController _qtdCtrl = TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    // Inicializa tabs e carrega dados iniciais.
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _carregar();
  }

  @override
  void dispose() {
    // Libera recursos da tela e controllers de texto.
    _tabController.dispose();
    _precoAtualCtrl.dispose();
    _novoPrecoCtrl.dispose();
    _qtdCtrl.dispose();
    super.dispose();
  }

  /// Carrega resumo, despesas e serie semanal para grafico.
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      _resumo = await _service.getResumo(_inicio, _fim);
      _despesas = await _service.getDespesas(inicio: _inicio, fim: _fim);
      _semanas = await _calcularSerieSemanal();
    } catch (e) {
      _erro('Falha ao carregar financeiro: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Monta serie das ultimas 4 semanas com receitas e despesas.
  Future<List<Map<String, double>>> _calcularSerieSemanal() async {
    final serie = <Map<String, double>>[];
    final hoje = DateTime.now();
    for (var i = 3; i >= 0; i--) {
      final fim = DateTime(hoje.year, hoje.month, hoje.day)
          .subtract(Duration(days: i * 7));
      final inicio = fim.subtract(const Duration(days: 6));
      final receita = await _atendimentoService.getFaturamentoPeriodo(inicio, fim);
      final despesa = await _service.getTotalDespesas(inicio, fim);
      serie.add({'receita': receita, 'despesa': despesa});
    }
    return serie;
  }

  /// Retorna despesas filtradas por categoria selecionada.
  List<Despesa> get _despesasFiltradas {
    if (_filtroCategoria == 'Todas') return _despesas;
    return _despesas.where((d) => d.categoria == _filtroCategoria).toList();
  }

  /// Exibe snackbar de erro em fundo vermelho.
  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  /// Exibe snackbar de sucesso em fundo verde.
  void _sucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(msg)),
    );
  }

  /// Aplica filtro predefinido de periodo para aba de resumo.
  Future<void> _setPeriodoRapido(String tipo) async {
    final now = DateTime.now();
    if (tipo == 'mes') {
      _inicio = DateTime(now.year, now.month, 1);
      _fim = now;
    } else if (tipo == '30') {
      _inicio = now.subtract(const Duration(days: 30));
      _fim = now;
    }
    await _carregar();
  }

  /// Abre date range picker para periodo personalizado.
  Future<void> _periodoCustomizado() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
    );
    if (range == null) return;
    _inicio = range.start;
    _fim = range.end;
    await _carregar();
  }

  /// Abre modal para cadastrar uma nova despesa.
  Future<void> _novaDespesa() async {
    final descricaoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    String categoria = 'Aluguel';
    DateTime data = DateTime.now();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nova despesa', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(controller: descricaoCtrl, decoration: const InputDecoration(labelText: 'Descricao *')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoria,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'Aluguel', child: Text('Aluguel')),
                      DropdownMenuItem(value: 'Luz', child: Text('Luz')),
                      DropdownMenuItem(value: 'Internet', child: Text('Internet')),
                      DropdownMenuItem(value: 'Compra de Produtos', child: Text('Compra de Produtos')),
                      DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                    ],
                    onChanged: (v) => setModalState(() => categoria = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor *'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
                    subtitle: Text(AppFormatters.date(data)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: data,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setModalState(() => data = d);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: obsCtrl, decoration: const InputDecoration(labelText: 'Observacoes')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar despesa'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;
    if (descricaoCtrl.text.trim().isEmpty) {
      _erro('Descricao obrigatoria');
      return;
    }
    final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      _erro('Valor invalido');
      return;
    }

    try {
      await _service.insertDespesa(
        Despesa(
          descricao: descricaoCtrl.text.trim(),
          categoria: categoria,
          valor: valor,
          data: data,
          observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        ),
      );
      _sucesso('Despesa cadastrada com sucesso');
      await _carregar();
    } catch (e) {
      _erro('Falha ao salvar despesa: $e');
    }
  }

  /// Exclui despesa selecionada apos confirmacao do usuario.
  Future<void> _deletarDespesa(Despesa d) async {
    if (d.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir despesa'),
        content: Text('Deseja excluir "${d.descricao}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _service.deleteDespesa(d.id!);
      _sucesso('Despesa removida com sucesso');
      await _carregar();
    } catch (e) {
      _erro('Falha ao remover despesa: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estrutura da tela financeira com tabs e drawer.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Resumo'),
            Tab(text: 'Despesas'),
            Tab(text: 'Simulador'),
          ],
        ),
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.financeiro),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _novaDespesa,
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_abaResumo(), _abaDespesas(), _abaSimulador()],
            ),
    );
  }

  /// Aba 1: cards de resumo, filtros de periodo e grafico semanal.
  Widget _abaResumo() {
    final faturamento = _resumo['faturamento'] ?? 0;
    final despesas = _resumo['despesas'] ?? 0;
    final lucro = _resumo['lucro'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(label: const Text('Este mes'), onPressed: () => _setPeriodoRapido('mes')),
            ActionChip(label: const Text('Ultimos 30 dias'), onPressed: () => _setPeriodoRapido('30')),
            ActionChip(label: const Text('Personalizado'), onPressed: _periodoCustomizado),
          ],
        ),
        const SizedBox(height: 8),
        Text('Periodo: ${AppFormatters.date(_inicio)} a ${AppFormatters.date(_fim)}'),
        const SizedBox(height: 10),
        _cardResumo('Faturamento Bruto', faturamento, AppTheme.infoColor, Icons.attach_money),
        _cardResumo('Total de Despesas', despesas, AppTheme.errorColor, Icons.money_off),
        _cardResumo('Lucro Liquido', lucro, lucro >= 0 ? AppTheme.successColor : AppTheme.errorColor, Icons.trending_up),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receitas vs Despesas (semanal)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(height: 220, child: _graficoSemanal()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Construtor reutilizavel para cards de resumo financeiro.
  Widget _cardResumo(String titulo, double valor, Color cor, IconData icone) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.2),
          child: Icon(icone, color: cor),
        ),
        title: Text(titulo),
        trailing: Text(
          AppFormatters.currency(valor),
          style: TextStyle(fontWeight: FontWeight.bold, color: cor),
        ),
      ),
    );
  }

  /// Monta grafico de barras com duas series: receita e despesa por semana.
  Widget _graficoSemanal() {
    if (_semanas.isEmpty) return const Center(child: Text('Sem dados semanais'));

    final maxY = _semanas
            .map((e) => (e['receita']! > e['despesa']! ? e['receita']! : e['despesa']!))
            .reduce((a, b) => a > b ? a : b) *
        1.3;

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text('S${value.toInt() + 1}'),
            ),
          ),
        ),
        barGroups: _semanas.asMap().entries.map((e) {
          final idx = e.key;
          final receita = e.value['receita'] ?? 0;
          final despesa = e.value['despesa'] ?? 0;
          return BarChartGroupData(
            x: idx,
            barsSpace: 4,
            barRods: [
              BarChartRodData(toY: receita, width: 12, color: AppTheme.infoColor),
              BarChartRodData(toY: despesa, width: 12, color: AppTheme.errorColor),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Aba 2: lista de despesas com filtro por categoria e remocao por slide.
  Widget _abaDespesas() {
    final categorias = ['Todas', 'Aluguel', 'Luz', 'Internet', 'Compra de Produtos', 'Outros'];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: categorias
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _filtroCategoria == c,
                      onSelected: (_) => setState(() => _filtroCategoria = c),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: _despesasFiltradas.isEmpty
              ? const Center(child: Text('Nenhuma despesa para o filtro atual'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _despesasFiltradas.length,
                  itemBuilder: (context, i) {
                    final d = _despesasFiltradas[i];
                    return Slidable(
                      key: ValueKey(d.id),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => _deletarDespesa(d),
                            icon: Icons.delete,
                            label: 'Excluir',
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: Colors.white,
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt),
                          title: Text(d.descricao),
                          subtitle: Text('${d.categoria} - ${AppFormatters.date(d.data)}'),
                          trailing: Text(
                            AppFormatters.currency(d.valor),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Aba 3: simulador standalone de impacto de preco mensal e anual.
  Widget _abaSimulador() {
    final precoAtual = double.tryParse(_precoAtualCtrl.text.replaceAll(',', '.'));
    final novoPreco = double.tryParse(_novoPrecoCtrl.text.replaceAll(',', '.'));
    final qtdMes = int.tryParse(_qtdCtrl.text);

    final mensal = (precoAtual != null && novoPreco != null && qtdMes != null)
        ? (novoPreco - precoAtual) * qtdMes
        : 0.0;
    final anual = mensal * 12;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _precoAtualCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Preco Atual'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _novoPrecoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Novo Preco'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _qtdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Atendimentos/mes'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Diferenca mensal: ${AppFormatters.currency(mensal)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: mensal >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                    )),
                const SizedBox(height: 8),
                Text('Diferenca anual: ${AppFormatters.currency(anual)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: anual >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}





