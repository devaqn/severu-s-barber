// ============================================================
// novo_atendimento_screen.dart
// Fluxo de cadastro de atendimento usando Stepper em 3 etapas.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/atendimento.dart';
import '../../models/cliente.dart';
import '../../models/produto.dart';
import '../../models/servico.dart';
import '../../services/atendimento_service.dart';
import '../../services/cliente_service.dart';
import '../../services/produto_service.dart';
import '../../services/servico_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// Tela de novo atendimento com selecao de cliente, itens e pagamento.
class NovoAtendimentoScreen extends StatefulWidget {
  /// Construtor padrao da tela de novo atendimento.
  const NovoAtendimentoScreen({super.key});

  @override
  State<NovoAtendimentoScreen> createState() => _NovoAtendimentoScreenState();
}

/// Estado do stepper de atendimento com calculo dinamico de total.
class _NovoAtendimentoScreenState extends State<NovoAtendimentoScreen> {
  // Services usados para busca de dados e persistencia final.
  final ClienteService _clienteService = ClienteService();
  final ServicoService _servicoService = ServicoService();
  final ProdutoService _produtoService = ProdutoService();
  final AtendimentoService _atendimentoService = AtendimentoService();

  // Estado de navegacao entre etapas do Stepper.
  int _step = 0;

  // Estado de carregamento inicial de dados referenciais.
  bool _loading = true;

  // Campo de busca de cliente para autocomplete simples.
  final TextEditingController _buscaClienteCtrl = TextEditingController();

  // Cliente selecionado ou null para atendimento avulso.
  Cliente? _clienteSelecionado;

  // Flag para operar como cliente avulso.
  bool _clienteAvulso = false;

  // Nome digitado quando atendimento e avulso.
  final TextEditingController _nomeAvulsoCtrl = TextEditingController();

  // Listas carregadas de servicos e produtos ativos.
  List<Servico> _servicos = [];
  List<Produto> _produtos = [];
  List<Cliente> _sugestoesClientes = [];

  // Selecao de servicos via map de id.
  final Map<int, bool> _servicosSelecionados = {};

  // Quantidades de produtos selecionados por id.
  final Map<int, int> _qtdProdutos = {};

  // Forma de pagamento atual da etapa 3.
  String _formaPagamento = AppConstants.pgDinheiro;

  // Observacao livre do atendimento.
  final TextEditingController _obsCtrl = TextEditingController();

  // Flag para travar UI durante finalizacao.
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Carrega dados base da tela ao abrir.
    _carregarBase();
    _buscaClienteCtrl.addListener(_buscarClientes);
  }

  @override
  void dispose() {
    // Libera recursos de campos de texto.
    _buscaClienteCtrl.dispose();
    _nomeAvulsoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  /// Carrega servicos e produtos para selecao nas etapas.
  Future<void> _carregarBase() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _servicoService.getAll(apenasAtivos: true),
        _produtoService.getAll(apenasAtivos: true),
      ]);
      _servicos = results[0] as List<Servico>;
      _produtos = results[1] as List<Produto>;
      for (final s in _servicos) {
        if (s.id != null) _servicosSelecionados[s.id!] = false;
      }
    } catch (e) {
      _erro('Falha ao carregar dados: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Busca clientes por nome para sugestao durante digitacao.
  Future<void> _buscarClientes() async {
    if (_clienteAvulso) return;
    final q = _buscaClienteCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _sugestoesClientes = []);
      return;
    }
    try {
      final list = await _clienteService.search(q);
      if (mounted) setState(() => _sugestoesClientes = list);
    } catch (_) {
      // Falha de busca nao bloqueia fluxo de cadastro.
    }
  }

  /// Calcula total parcial considerando servicos e produtos selecionados.
  double get _total {
    double total = 0;
    for (final s in _servicos) {
      if ((s.id != null) && (_servicosSelecionados[s.id!] ?? false)) {
        total += s.preco;
      }
    }
    for (final p in _produtos) {
      final qtd = _qtdProdutos[p.id ?? -1] ?? 0;
      if (qtd > 0) total += p.precoVenda * qtd;
    }
    return total;
  }

  /// Exibe snackbar de erro padrao em vermelho.
  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  /// Exibe snackbar de sucesso padrao em verde.
  void _sucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(msg)),
    );
  }

  /// Valida etapa atual antes de avancar no stepper.
  bool _validarStepAtual() {
    if (_step == 0) {
      if (_clienteAvulso && _nomeAvulsoCtrl.text.trim().isEmpty) {
        _erro('Informe o nome do cliente avulso');
        return false;
      }
      if (!_clienteAvulso && _clienteSelecionado == null) {
        _erro('Selecione um cliente ou marque cliente avulso');
        return false;
      }
    }
    if (_step == 1) {
      final temServico = _servicosSelecionados.values.any((v) => v);
      final temProduto = _qtdProdutos.values.any((q) => q > 0);
      if (!temServico && !temProduto) {
        _erro('Selecione ao menos um servico ou produto');
        return false;
      }
    }
    return true;
  }

  /// Finaliza atendimento persistindo registro e efeitos colaterais.
  Future<void> _finalizar() async {
    if (_total <= 0) {
      _erro('Total invalido para finalizar atendimento');
      return;
    }

    setState(() => _salvando = true);
    try {
      // Monta lista final de itens a partir da selecao do usuario.
      final itens = <AtendimentoItem>[];
      for (final s in _servicos) {
        if (s.id != null && (_servicosSelecionados[s.id!] ?? false)) {
          itens.add(
            AtendimentoItem(
              tipo: 'servico',
              itemId: s.id!,
              nome: s.nome,
              quantidade: 1,
              precoUnitario: s.preco,
            ),
          );
        }
      }
      for (final p in _produtos) {
        final qtd = _qtdProdutos[p.id ?? -1] ?? 0;
        if (p.id != null && qtd > 0) {
          itens.add(
            AtendimentoItem(
              tipo: 'produto',
              itemId: p.id!,
              nome: p.nome,
              quantidade: qtd,
              precoUnitario: p.precoVenda,
            ),
          );
        }
      }

      // Cria model de atendimento consolidado da operacao.
      final atendimento = Atendimento(
        clienteId: _clienteAvulso ? null : _clienteSelecionado?.id,
        clienteNome: _clienteAvulso
            ? _nomeAvulsoCtrl.text.trim()
            : _clienteSelecionado!.nome,
        total: _total,
        formaPagamento: _formaPagamento,
        data: DateTime.now(),
        observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        itens: itens,
      );

      // Persiste atendimento com todos os efeitos em transacao atomica.
      await _atendimentoService.registrar(atendimento);

      // Fecha tela com feedback visual de sucesso.
      if (mounted) {
        _sucesso('Atendimento registrado com sucesso');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _erro('Falha ao finalizar atendimento: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Avanca para proxima etapa apos validacao.
  void _continuar() {
    if (_salvando) return;
    if (!_validarStepAtual()) return;
    if (_step < 2) {
      setState(() => _step += 1);
    } else {
      _finalizar();
    }
  }

  /// Retorna para a etapa anterior.
  void _voltar() {
    if (_salvando) return;
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estado de carregamento inicial da tela.
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Layout do fluxo customizado de cadastro de atendimento.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Novo Atendimento',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(_step),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildStepBody(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _step == 0 || _salvando ? null : _voltar,
                    child: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _step == 2
                      ? Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.accentColor,
                                AppTheme.accentDark
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: _salvando ? null : _continuar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppTheme.primaryColor.withValues(alpha: 0),
                              shadowColor:
                                  AppTheme.primaryColor.withValues(alpha: 0),
                            ),
                            child: _salvando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    'Finalizar Atendimento',
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _continuar,
                          child: const Text('Continuar'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Desenha o indicador visual customizado com 3 etapas.
  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(3, (index) {
        final ativo = _step == index;
        final concluido = _step > index;
        final circleColor = concluido
            ? AppTheme.successColor
            : ativo
                ? AppTheme.accentColor
                : AppTheme.primaryColor.withValues(alpha: 0);

        return Expanded(
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() => _step = index),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: circleColor,
                    borderRadius: BorderRadius.circular(17),
                    border: concluido || ativo
                        ? null
                        : Border.all(color: AppTheme.textSecondary),
                  ),
                  child: Center(
                    child: concluido
                        ? const Icon(Icons.check,
                            color: AppTheme.textPrimary, size: 18)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              color: ativo
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              if (index < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: _step > index
                        ? AppTheme.accentColor
                        : AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// Monta o corpo da etapa atual.
  Widget _buildStepBody() {
    if (_step == 0) return _passoCliente();
    if (_step == 1) return _passoItens();
    return _passoPagamento();
  }

  /// Etapa 1: selecao de cliente com opcao de atendimento avulso.
  Widget _passoCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: _clienteAvulso,
          activeThumbColor: AppTheme.accentColor,
          onChanged: (v) {
            setState(() {
              _clienteAvulso = v;
              _clienteSelecionado = null;
              _sugestoesClientes = [];
              _buscaClienteCtrl.clear();
            });
          },
          title: const Text('Cliente avulso'),
        ),
        const SizedBox(height: 8),
        if (_clienteAvulso)
          TextField(
            controller: _nomeAvulsoCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome do cliente avulso',
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
          const SizedBox(height: 8),
          if (_sugestoesClientes.isEmpty)
            Text(
              'Digite ao menos 2 letras para buscar',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            )
          else
            RadioGroup<Cliente>(
              groupValue: _clienteSelecionado,
              onChanged: (v) => setState(() => _clienteSelecionado = v),
              child: Column(
                children: _sugestoesClientes
                    .take(6)
                    .map(
                      (c) => RadioListTile<Cliente>(
                        value: c,
                        activeColor: AppTheme.accentColor,
                        title: Text(c.nome),
                        subtitle: Text(c.telefone),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ],
    );
  }

  /// Etapa 2: selecao multipla de servicos e quantidades de produtos.
  Widget _passoItens() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Servicos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ..._servicos.map(
          (s) {
            final checked = _servicosSelecionados[s.id] ?? false;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: checked
                    ? AppTheme.accentColor.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      checked ? AppTheme.accentColor : AppTheme.secondaryColor,
                  width: checked ? 2 : 1,
                ),
              ),
              child: CheckboxListTile(
                value: checked,
                activeColor: AppTheme.accentColor,
                title: Text('${s.nome} - ${AppFormatters.currency(s.preco)}'),
                subtitle: Text('Duracao: ${s.duracaoMinutos} min'),
                onChanged: (v) {
                  setState(() => _servicosSelecionados[s.id!] = v ?? false);
                },
              ),
            );
          },
        ),
        const Divider(height: 20),
        Text('Produtos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ..._produtos.map(
          (p) {
            final qtd = _qtdProdutos[p.id ?? -1] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nome,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppFormatters.currency(p.precoVenda),
                          style:
                              GoogleFonts.inter(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _qtdButton(
                    icon: Icons.remove,
                    onTap: qtd > 0
                        ? () => setState(() => _qtdProdutos[p.id!] = qtd - 1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$qtd',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _qtdButton(
                    icon: Icons.add,
                    onTap: () => setState(() => _qtdProdutos[p.id!] = qtd + 1),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Total parcial: ${AppFormatters.currency(_total)}',
          style: GoogleFonts.poppins(
            color: AppTheme.successColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Cria botao circular usado no spinner de quantidade.
  Widget _qtdButton({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap == null ? AppTheme.textSecondary : AppTheme.accentColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppTheme.textPrimary),
      ),
    );
  }

  /// Etapa 3: confirmacao de pagamento e finalizacao do atendimento.
  Widget _passoPagamento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total: ${AppFormatters.currency(_total)}',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: AppConstants.pgDinheiro, label: Text('Dinheiro')),
            ButtonSegment(value: AppConstants.pgPix, label: Text('PIX')),
            ButtonSegment(value: AppConstants.pgCredito, label: Text('Cartao')),
          ],
          selected: {_formaPagamento},
          onSelectionChanged: (value) {
            setState(() => _formaPagamento = value.first);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _obsCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Observacoes',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
