// ============================================================
// abrir_comanda_screen.dart
// Tela para abrir uma nova comanda ou continuar uma existente.
// Permite selecionar cliente, adicionar serviços e produtos.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/cliente_controller.dart';
import '../../controllers/comanda_controller.dart';
import '../../controllers/produto_controller.dart';
import '../../controllers/servico_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/cliente.dart';
import '../../models/comanda.dart';
import '../../models/item_comanda.dart';
import '../../models/produto.dart';
import '../../models/servico.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// Tela de abertura e gerenciamento de comanda.
class AbrirComandaScreen extends StatefulWidget {
  /// Se informado, continua uma comanda já aberta
  final Comanda? comandaExistente;

  const AbrirComandaScreen({super.key, this.comandaExistente});

  @override
  State<AbrirComandaScreen> createState() => _AbrirComandaScreenState();
}

class _AbrirComandaScreenState extends State<AbrirComandaScreen> {
  ClienteController get _clienteController => context.read<ClienteController>();
  ServicoController get _servicoController => context.read<ServicoController>();
  ProdutoController get _produtoController => context.read<ProdutoController>();
  ComandaController get _comandaController => context.read<ComandaController>();

  final _buscaClienteCtrl = TextEditingController();
  bool _loading = true;
  bool _salvando = false;

  // Dados carregados
  List<Servico> _servicos = [];
  List<Produto> _produtos = [];
  List<Cliente> _sugestoesClientes = [];

  // Estado da comanda
  Comanda? _comanda;
  Cliente? _clienteSelecionado;
  bool _clienteAvulso = false;
  final _nomeAvulsoCtrl = TextEditingController();

  // Itens adicionados
  final Map<int, bool> _servicosSelecionados = {};
  final Map<int, int> _qtdProdutos = {};

  // Pagamento para fechamento
  String _formaPagamento = AppConstants.pgDinheiro;

  @override
  void initState() {
    super.initState();
    _comanda = widget.comandaExistente;
    _carregarBase();
    _buscaClienteCtrl.addListener(_buscarClientes);
  }

  @override
  void dispose() {
    _buscaClienteCtrl.dispose();
    _nomeAvulsoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarBase() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _servicoController.getAll(apenasAtivos: true),
        _produtoController.getAll(apenasAtivos: true),
      ]);
      _servicos = results[0] as List<Servico>;
      _produtos = results[1] as List<Produto>;
      for (final s in _servicos) {
        if (s.id != null) _servicosSelecionados[s.id!] = false;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buscarClientes() async {
    if (_clienteAvulso) return;
    final q = _buscaClienteCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _sugestoesClientes = []);
      return;
    }
    final list = await _clienteController.search(q);
    if (mounted) setState(() => _sugestoesClientes = list);
  }

  /// Calcula o total dos itens selecionados
  double get _totalItens {
    double total = 0;
    for (final s in _servicos) {
      if ((_servicosSelecionados[s.id] ?? false)) total += s.preco;
    }
    for (final p in _produtos) {
      final qtd = _qtdProdutos[p.id ?? -1] ?? 0;
      if (qtd > 0) total += p.precoVenda * qtd;
    }
    return total;
  }

  /// Abre a comanda no banco se ainda não foi aberta
  Future<void> _abrirComanda() async {
    if (_comanda != null) return; // já existe

    // Validação do cliente
    if (!_clienteAvulso && _clienteSelecionado == null) {
      _showError('Selecione um cliente ou use atendimento avulso');
      return;
    }
    if (_clienteAvulso && _nomeAvulsoCtrl.text.trim().isEmpty) {
      _showError('Informe o nome do cliente avulso');
      return;
    }

    final ctrl = context.read<AuthController>();
    setState(() => _salvando = true);
    try {
      final comanda = await _comandaController.abrirComanda(
        clienteId: _clienteSelecionado?.id,
        clienteNome: _clienteAvulso
            ? _nomeAvulsoCtrl.text.trim()
            : _clienteSelecionado!.nome,
        barbeiroId: ctrl.usuarioId.isNotEmpty ? ctrl.usuarioId : null,
        barbeiroNome: ctrl.usuarioNome.isNotEmpty ? ctrl.usuarioNome : null,
      );
      setState(() => _comanda = comanda);
    } catch (e) {
      _showError('Erro ao abrir comanda: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Adiciona os itens selecionados à comanda já aberta
  Future<void> _adicionarItens() async {
    if (_comanda == null) await _abrirComanda();
    if (_comanda == null) return;

    final temServico = _servicosSelecionados.values.any((v) => v);
    final temProduto = _qtdProdutos.values.any((q) => q > 0);
    if (!temServico && !temProduto) {
      _showError('Selecione ao menos um item');
      return;
    }

    setState(() => _salvando = true);
    try {
      // Adiciona serviços
      for (final s in _servicos) {
        if (_servicosSelecionados[s.id] == true) {
          await _comandaController.adicionarItem(
            _comanda!.id!,
            ItemComanda(
              tipo: 'servico',
              itemId: s.id!,
              nome: s.nome,
              quantidade: 1,
              precoUnitario: s.preco,
              comissaoPercentual: s.comissaoPercentual,
            ),
          );
        }
      }

      // Adiciona produtos
      for (final p in _produtos) {
        final qtd = _qtdProdutos[p.id ?? -1] ?? 0;
        if (qtd > 0 && p.id != null) {
          await _comandaController.adicionarItem(
            _comanda!.id!,
            ItemComanda(
              tipo: 'produto',
              itemId: p.id!,
              nome: p.nome,
              quantidade: qtd,
              precoUnitario: p.precoVenda,
              comissaoPercentual: p.comissaoPercentual,
            ),
          );
        }
      }

      // Recarrega comanda atualizada
      final atualizada = await _comandaController.getById(_comanda!.id!);
      setState(() {
        _comanda = atualizada;
        // Limpa seleções
        for (final k in _servicosSelecionados.keys) {
          _servicosSelecionados[k] = false;
        }
        _qtdProdutos.clear();
      });

      _showSuccess('Itens adicionados!');
    } catch (e) {
      _showError('Erro ao adicionar itens: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Fecha a comanda e registra comissões
  Future<void> _fecharComanda() async {
    if (_comanda == null || (_comanda!.itens.isEmpty && _comanda!.total <= 0)) {
      _showError('Adicione itens antes de fechar');
      return;
    }

    setState(() => _salvando = true);
    try {
      await _comandaController.fecharComanda(
        comandaId: _comanda!.id!,
        formaPagamento: _formaPagamento,
      );
      if (mounted) {
        _showSuccess('Comanda fechada com sucesso!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Erro ao fechar comanda: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _comanda == null ? 'Nova Comanda' : 'Comanda #${_comanda!.id}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seção do cliente (só exibe antes de abrir a comanda)
            if (_comanda == null) ...[
              _buildSecao('Cliente'),
              _buildSeletorCliente(),
              const SizedBox(height: 16),
            ] else
              _buildComandaResumo(),

            const SizedBox(height: 8),

            // Serviços
            _buildSecao('Serviços'),
            ..._servicos.map((s) => _buildServicoTile(s)),
            const SizedBox(height: 12),

            // Produtos
            _buildSecao('Produtos'),
            ..._produtos.map((p) => _buildProdutoTile(p)),
            const SizedBox(height: 16),

            // Total parcial
            if (_totalItens > 0)
              Text(
                'Subtotal selecionado: ${AppFormatters.currency(_totalItens)}',
                style: GoogleFonts.poppins(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),

            // Formas de pagamento (só após itens adicionados)
            if (_comanda != null && _comanda!.total > 0) ...[
              _buildSecao('Forma de Pagamento'),
              SegmentedButton<String>(
                segments: AppConstants.formasPagamento
                    .map((f) => ButtonSegment(
                        value: f,
                        label: Text(f, style: const TextStyle(fontSize: 12))))
                    .toList(),
                selected: {_formaPagamento},
                onSelectionChanged: (s) =>
                    setState(() => _formaPagamento = s.first),
              ),
              const SizedBox(height: 20),
            ],

            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _salvando ? null : _adicionarItens,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _comanda == null
                          ? 'Abrir e Adicionar'
                          : 'Adicionar Itens',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.infoColor,
                    ),
                  ),
                ),
                if (_comanda != null && _comanda!.total > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _salvando ? null : _fecharComanda,
                      icon: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        'Fechar',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecao(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildComandaResumo() {
    final c = _comanda!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.clienteNome,
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  )),
              Text(
                '${c.itens.length} item(ns)',
                style: GoogleFonts.inter(color: AppTheme.textSecondary),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.currency(c.total),
                style: GoogleFonts.poppins(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text(
                'Comissão: ${AppFormatters.currency(c.comissaoTotal)}',
                style:
                    GoogleFonts.inter(color: AppTheme.goldColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeletorCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: _clienteAvulso,
          activeThumbColor: AppTheme.accentColor,
          title: const Text('Cliente avulso'),
          onChanged: (v) => setState(() {
            _clienteAvulso = v;
            _clienteSelecionado = null;
            _sugestoesClientes = [];
            _buscaClienteCtrl.clear();
          }),
        ),
        if (_clienteAvulso)
          TextField(
            controller: _nomeAvulsoCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome do cliente',
              prefixIcon: Icon(Icons.person),
            ),
          )
        else ...[
          TextField(
            controller: _buscaClienteCtrl,
            decoration: const InputDecoration(
              labelText: 'Buscar cliente',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (_sugestoesClientes.isNotEmpty)
            RadioGroup<Cliente>(
              groupValue: _clienteSelecionado,
              onChanged: (v) => setState(() => _clienteSelecionado = v),
              child: Column(
                children: _sugestoesClientes.take(5).map((c) {
                  return InkWell(
                    onTap: () => setState(() => _clienteSelecionado = c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Radio<Cliente>(
                            value: c,
                            activeColor: AppTheme.accentColor,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.nome),
                                Text(
                                  c.telefone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildServicoTile(Servico s) {
    final checked = _servicosSelecionados[s.id] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: checked
            ? AppTheme.accentColor.withValues(alpha: 0.1)
            : AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked ? AppTheme.accentColor : AppTheme.secondaryColor,
        ),
      ),
      child: CheckboxListTile(
        value: checked,
        activeColor: AppTheme.accentColor,
        title: Text('${s.nome} — ${AppFormatters.currency(s.preco)}'),
        subtitle: Text(
          'Comissão: ${(s.comissaoPercentual * 100).toStringAsFixed(0)}%  •  ${s.duracaoMinutos} min',
          style: const TextStyle(fontSize: 12),
        ),
        onChanged: (v) =>
            setState(() => _servicosSelecionados[s.id!] = v ?? false),
      ),
    );
  }

  Widget _buildProdutoTile(Produto p) {
    final qtd = _qtdProdutos[p.id ?? -1] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nome,
                    style: GoogleFonts.poppins(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                Text(
                  '${AppFormatters.currency(p.precoVenda)}  •  Comissão: ${(p.comissaoPercentual * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Spinner de quantidade
          _qtdBtn(
              Icons.remove,
              qtd > 0
                  ? () => setState(() => _qtdProdutos[p.id!] = qtd - 1)
                  : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('$qtd',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                )),
          ),
          _qtdBtn(
              Icons.add, () => setState(() => _qtdProdutos[p.id!] = qtd + 1)),
        ],
      ),
    );
  }

  Widget _qtdBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap == null ? AppTheme.textSecondary : AppTheme.accentColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}
