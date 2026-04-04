// ============================================================
// produtos_screen.dart
// Tela de listagem de produtos com busca, filtros e acoes rapidas.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import 'produto_form_screen.dart';

/// Tela de produtos com filtros por estoque e busca textual.
class ProdutosScreen extends StatefulWidget {
  /// Construtor padrao da tela de produtos.
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

/// Estado da tela de produtos com filtro local e operacoes CRUD.
class _ProdutosScreenState extends State<ProdutosScreen> {
  // Servico de dados de produtos.
  final ProdutoService _service = ProdutoService();

  // Controlador do texto de busca.
  final TextEditingController _buscaCtrl = TextEditingController();

  // Lista completa carregada do banco.
  List<Produto> _produtos = [];

  // Lista filtrada exibida na UI.
  List<Produto> _filtrados = [];

  // Estado de carregamento da tela.
  bool _loading = true;

  // Flag para mostrar campo de busca no appbar.
  bool _mostrarBusca = false;

  // Filtro ativo de estoque no topo da tela.
  String _filtro = 'Todos';

  @override
  void initState() {
    super.initState();
    // Carrega dados iniciais ao abrir a tela.
    _carregar();
    _buscaCtrl.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    // Libera recursos do controlador de busca.
    _buscaCtrl.dispose();
    super.dispose();
  }

  /// Carrega todos os produtos e aplica filtros correntes.
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      _produtos = await _service.getAll(apenasAtivos: false);
      _aplicarFiltros();
    } catch (e) {
      _erro('Falha ao carregar produtos: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Aplica busca textual e filtro por status de estoque.
  void _aplicarFiltros() {
    final q = _buscaCtrl.text.trim().toLowerCase();
    var lista = _produtos.where((p) => p.ativo).toList();

    if (q.isNotEmpty) {
      lista = lista.where((p) => p.nome.toLowerCase().contains(q)).toList();
    }

    if (_filtro == 'Estoque Baixo') {
      lista = lista.where((p) => p.estoqueBaixo).toList();
    } else if (_filtro == 'Sem Estoque') {
      lista = lista.where((p) => p.quantidade <= 0).toList();
    }

    setState(() => _filtrados = lista);
  }

  /// Exibe erro padrao em snackbar vermelho.
  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  /// Exibe sucesso padrao em snackbar verde.
  void _sucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(msg)),
    );
  }

  /// Abre formulario de produto para criacao ou edicao.
  Future<void> _abrirFormulario({Produto? produto}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProdutoFormScreen(produto: produto)),
    );
    await _carregar();
  }

  /// Desativa produto mantendo historico de vendas.
  Future<void> _desativar(Produto produto) async {
    try {
      if (produto.id == null) return;
      await _service.delete(produto.id!);
      _sucesso('Produto desativado com sucesso');
      await _carregar();
    } catch (e) {
      _erro('Falha ao desativar produto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela principal de produtos com drawer e filtros.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: _mostrarBusca
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentColor),
                ),
                child: TextField(
                  controller: _buscaCtrl,
                  autofocus: true,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar produto',
                    hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              )
            : Text(
                'Produtos',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 18),
              ),
        actions: [
          IconButton(
            icon: Icon(_mostrarBusca ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _mostrarBusca = !_mostrarBusca;
                if (!_mostrarBusca) {
                  _buscaCtrl.clear();
                }
              });
            },
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.produtos),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentColor,
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add, color: AppTheme.textPrimary),
      ),
      body: Column(
        children: [
          // Filtros superiores de estoque por chips selecionaveis.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: ['Todos', 'Estoque Baixo', 'Sem Estoque']
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: _filtro == f,
                        selectedColor: AppTheme.accentColor,
                        labelStyle: GoogleFonts.inter(
                          color: _filtro == f
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                        onSelected: (_) {
                          setState(() => _filtro = f);
                          _aplicarFiltros();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtrados.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum produto encontrado',
                          style:
                              GoogleFonts.inter(color: AppTheme.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtrados.length,
                          itemBuilder: (context, index) {
                            final p = _filtrados[index];
                            final margem = p.margemLucroPercent * 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Slidable(
                                key: ValueKey(p.id),
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  children: [
                                    SlidableAction(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                      ),
                                      onPressed: (_) =>
                                          _abrirFormulario(produto: p),
                                      icon: Icons.edit,
                                      label: 'Editar',
                                      backgroundColor: AppTheme.infoColor,
                                      foregroundColor: AppTheme.textPrimary,
                                    ),
                                    SlidableAction(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                      onPressed: (_) => _desativar(p),
                                      icon: Icons.block,
                                      label: 'Desativar',
                                      backgroundColor: AppTheme.errorColor,
                                      foregroundColor: AppTheme.textPrimary,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: p.estoqueBaixo
                                        ? Border.all(color: AppTheme.errorColor)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(14),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.successColor,
                                            AppTheme.successDark
                                          ],
                                        ),
                                      ),
                                      child: const Icon(Icons.inventory_2,
                                          color: AppTheme.textPrimary),
                                    ),
                                    title: Text(
                                      p.nome,
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Venda: ${AppFormatters.currency(p.precoVenda)}',
                                          style: GoogleFonts.inter(
                                              color: AppTheme.textSecondary),
                                        ),
                                        Text(
                                          'Custo: ${AppFormatters.currency(p.precoCusto)}',
                                          style: GoogleFonts.inter(
                                              color: AppTheme.textSecondary),
                                        ),
                                        Text(
                                          'Estoque: ${p.quantidade} un.  |  Margem: ${margem.toStringAsFixed(1)}%',
                                          style: GoogleFonts.inter(
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    trailing: p.estoqueBaixo
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.errorColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Baixo',
                                              style: GoogleFonts.inter(
                                                color: AppTheme.textPrimary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            AppFormatters.currency(
                                                p.precoVenda),
                                            style: GoogleFonts.poppins(
                                              color: AppTheme.successColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                    isThreeLine: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
