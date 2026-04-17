// ============================================================
// estoque_screen.dart
// Painel avancado de estoque com visao geral, movimentacoes e fornecedores.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../controllers/produto_controller.dart';
import '../../models/fornecedor.dart';
import '../../models/movimento_estoque.dart';
import '../../models/produto.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';

/// Tela de controle de estoque dividida em tres abas operacionais.
class EstoqueScreen extends StatefulWidget {
  /// Construtor padrao da tela de estoque.
  const EstoqueScreen({super.key});

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

/// Estado da tela de estoque com tab controller e dados consolidados.
class _EstoqueScreenState extends State<EstoqueScreen>
    with SingleTickerProviderStateMixin {
  ProdutoController get _produtoController => context.read<ProdutoController>();

  // Controlador de abas da tela.
  late TabController _tabController;

  // Estado de carregamento global da tela.
  bool _loading = true;

  // Dados de visao geral de estoque.
  double _valorTotal = 0;
  List<Produto> _baixo = [];
  List<Produto> _parados = [];
  List<Map<String, dynamic>> _reposicao = [];

  // Dados de movimentacoes e fornecedores.
  List<MovimentoEstoque> _movimentos = [];
  List<Fornecedor> _fornecedores = [];

  @override
  void initState() {
    super.initState();
    // Inicializa abas e carrega dados iniciais da tela.
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _carregar();
  }

  @override
  void dispose() {
    // Libera controlador de abas.
    _tabController.dispose();
    super.dispose();
  }

  /// Carrega todas as fontes de dados da tela em paralelo.
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _produtoController.getValorTotalEstoque(),
        _produtoController.getProdutosEstoqueBaixo(),
        _produtoController.getProdutosParados(),
        _produtoController.getSugestoesReposicao(),
        _produtoController.getMovimentos(),
        _produtoController.getFornecedores(),
      ]);
      _valorTotal = results[0] as double;
      _baixo = results[1] as List<Produto>;
      _parados = results[2] as List<Produto>;
      _reposicao = (results[3] as List).cast<Map<String, dynamic>>();
      _movimentos = results[4] as List<MovimentoEstoque>;
      _fornecedores = results[5] as List<Fornecedor>;
    } catch (e) {
      _erro('Falha ao carregar estoque: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Exibe erro em snackbar vermelho.
  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  /// Exibe sucesso em snackbar verde.
  void _sucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(msg)),
    );
  }

  /// Abre modal para registrar entrada manual de estoque.
  Future<void> _registrarEntradaManual() async {
    try {
      final produtos = await _produtoController.getAll();
      if (produtos.isEmpty) {
        _erro('Cadastre produtos antes de registrar entrada');
        return;
      }
      if (!mounted) return;
      int? produtoId = produtos.first.id;
      final qtdCtrl = TextEditingController(text: '1');
      final valorCtrl = TextEditingController(text: '0,00');
      final obsCtrl = TextEditingController();

      final confirmar = await showModalBottomSheet<bool>(
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
                    Text('Entrada manual de estoque',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: produtoId,
                      decoration: const InputDecoration(labelText: 'Produto'),
                      items: produtos
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.nome),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => produtoId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtdCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Quantidade'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Valor unitario'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obsCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Observacao'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.save),
                        label: const Text('Registrar Entrada'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (confirmar != true || produtoId == null) return;

      await _produtoController.entradaEstoque(
        produtoId: produtoId!,
        quantidade: int.tryParse(qtdCtrl.text) ?? 1,
        valorUnitario:
            double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0,
        observacao: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
      );
      _sucesso('Entrada registrada com sucesso');
      await _carregar();
    } catch (e) {
      _erro('Falha ao registrar entrada: $e');
    }
  }

  /// Abre modal para criar ou editar fornecedor.
  Future<void> _editarFornecedor({Fornecedor? fornecedor}) async {
    final nomeCtrl = TextEditingController(text: fornecedor?.nome ?? '');
    final telCtrl = TextEditingController(text: fornecedor?.telefone ?? '');
    final emailCtrl = TextEditingController(text: fornecedor?.email ?? '');
    final obsCtrl = TextEditingController(text: fornecedor?.observacoes ?? '');

    final salvar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
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
              Text(
                fornecedor == null ? 'Novo fornecedor' : 'Editar fornecedor',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome *')),
              const SizedBox(height: 12),
              TextField(
                  controller: telCtrl,
                  decoration: const InputDecoration(labelText: 'Telefone')),
              const SizedBox(height: 12),
              TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(labelText: 'Observacoes')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar fornecedor'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (salvar != true) return;
    if (nomeCtrl.text.trim().isEmpty) {
      _erro('Informe o nome do fornecedor');
      return;
    }

    try {
      final model = Fornecedor(
        id: fornecedor?.id,
        nome: nomeCtrl.text.trim(),
        telefone: telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
        email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
        observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        createdAt: fornecedor?.createdAt ?? DateTime.now(),
      );
      if (fornecedor == null) {
        await _produtoController.insertFornecedor(model);
        _sucesso('Fornecedor cadastrado');
      } else {
        await _produtoController.updateFornecedor(model);
        _sucesso('Fornecedor atualizado');
      }
      await _carregar();
    } catch (e) {
      _erro('Falha ao salvar fornecedor: $e');
    }
  }

  /// Exclui fornecedor selecionado apos confirmacao do usuario.
  Future<void> _deletarFornecedor(Fornecedor f) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir fornecedor'),
        content: Text('Deseja remover ${f.nome}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || f.id == null) return;

    try {
      await _produtoController.deleteFornecedor(f.id!);
      _sucesso('Fornecedor removido');
      await _carregar();
    } catch (e) {
      _erro('Falha ao remover fornecedor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estrutura principal com tabs e drawer lateral.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black87,
          tabs: const [
            Tab(text: 'Visao Geral'),
            Tab(text: 'Movimentacoes'),
            Tab(text: 'Fornecedores'),
          ],
        ),
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.estoque),
      floatingActionButton: _buildFab(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _abaVisaoGeral(),
                _abaMovimentacoes(),
                _abaFornecedores(),
              ],
            ),
    );
  }

  /// Retorna FAB dinamico de acordo com a aba ativa.
  Widget? _buildFab() {
    if (_tabController.index == 1) {
      return FloatingActionButton(
        onPressed: _registrarEntradaManual,
        child: const Icon(Icons.add),
      );
    }
    if (_tabController.index == 2) {
      return FloatingActionButton(
        onPressed: () => _editarFornecedor(),
        child: const Icon(Icons.person_add),
      );
    }
    return null;
  }

  /// Aba 1: resumo de estoque baixo, produtos parados e sugestoes de reposicao.
  Widget _abaVisaoGeral() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments, color: AppTheme.infoColor),
            title: const Text('Valor total investido em estoque'),
            trailing: Text(
              AppFormatters.currency(_valorTotal),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.warning, color: AppTheme.errorColor),
            title: const Text('Produtos com estoque baixo'),
            trailing: Text(
              '${_baixo.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Estoque baixo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (_baixo.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Nenhum alerta de estoque baixo')))
        else
          ..._baixo.map((p) => Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.inventory_2, color: AppTheme.errorColor),
                  title: Text(p.nome),
                  subtitle: Text(
                      'Atual: ${p.quantidade} | Minimo: ${p.estoqueMinimo}'),
                ),
              )),
        const SizedBox(height: 8),
        Text('Produtos parados (60+ dias)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (_parados.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Nenhum produto parado')))
        else
          ..._parados.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.hourglass_bottom,
                      color: AppTheme.warningColor),
                  title: Text(p.nome),
                  subtitle: Text('Estoque: ${p.quantidade}'),
                ),
              )),
        const SizedBox(height: 8),
        Text('Sugestoes de reposicao',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (_reposicao.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Sem sugestoes no momento')))
        else
          ..._reposicao.map((m) => Card(
                child: ListTile(
                  leading: const Icon(Icons.shopping_cart,
                      color: AppTheme.accentColor),
                  title: Text('${m['nome']}'),
                  subtitle: Text(
                      'Estoque atual: ${m['estoque_atual']} | Saidas 30d: ${m['saidas_30dias']}'),
                  trailing: Text(
                    'Sug.: ${m['quantidade_sugerida']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )),
      ],
    );
  }

  /// Aba 2: historico de movimentacoes com cores por tipo.
  Widget _abaMovimentacoes() {
    if (_movimentos.isEmpty) {
      return const Center(child: Text('Nenhuma movimentacao registrada'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _movimentos.length,
      itemBuilder: (context, i) {
        final m = _movimentos[i];
        final entrada = m.tipo == AppConstants.estoqueEntrada;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  (entrada ? AppTheme.successColor : AppTheme.errorColor)
                      .withValues(alpha: 0.2),
              child: Icon(
                entrada ? Icons.arrow_downward : Icons.arrow_upward,
                color: entrada ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ),
            title: Text(m.produtoNome),
            subtitle: Text(
                '${entrada ? 'Entrada' : 'Saida'} de ${m.quantidade} un.\n${AppFormatters.dateTime(m.data)}'),
            trailing: Text(
              AppFormatters.currency(m.valorTotal),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  /// Aba 3: lista de fornecedores com acoes de editar/remover via slidable.
  Widget _abaFornecedores() {
    if (_fornecedores.isEmpty) {
      return const Center(child: Text('Nenhum fornecedor cadastrado'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fornecedores.length,
      itemBuilder: (context, i) {
        final f = _fornecedores[i];
        return Slidable(
          key: ValueKey(f.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => _editarFornecedor(fornecedor: f),
                icon: Icons.edit,
                label: 'Editar',
                backgroundColor: AppTheme.infoColor,
                foregroundColor: Colors.white,
              ),
              SlidableAction(
                onPressed: (_) => _deletarFornecedor(f),
                icon: Icons.delete,
                label: 'Excluir',
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
            ],
          ),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.business),
              title: Text(f.nome),
              subtitle: Text('${f.telefone ?? '-'}\n${f.email ?? '-'}'),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }
}
