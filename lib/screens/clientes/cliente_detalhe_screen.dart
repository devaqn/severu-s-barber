// ============================================================
// cliente_detalhe_screen.dart
// Tela de detalhe do cliente com fidelidade e historico.
// ============================================================

import 'package:flutter/material.dart';
import '../../models/atendimento.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'cliente_form_screen.dart';

/// Tela de detalhe completa de um cliente selecionado na lista.
class ClienteDetalheScreen extends StatefulWidget {
  /// Cliente base recebido para abrir a tela.
  final Cliente cliente;

  /// Construtor padrao da tela de detalhes.
  const ClienteDetalheScreen({super.key, required this.cliente});

  @override
  State<ClienteDetalheScreen> createState() => _ClienteDetalheScreenState();
}

/// Estado da tela de detalhes com recarga de cliente e historico.
class _ClienteDetalheScreenState extends State<ClienteDetalheScreen> {
  // Servico para consultar e atualizar dados do cliente.
  final ClienteService _service = ClienteService();

  // Snapshot atual do cliente usado para renderizacao.
  Cliente? _cliente;

  // Historico de atendimentos associado ao cliente.
  List<Atendimento> _historico = [];

  // Estado de carregamento geral da tela.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Carrega dados atualizados ao abrir a tela.
    _carregar();
  }

  /// Carrega cliente atualizado e historico em paralelo.
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getById(widget.cliente.id!),
        _service.getHistorico(widget.cliente.id!),
      ]);
      if (!mounted) return;
      setState(() {
        _cliente = results[0] as Cliente?;
        _historico = results[1] as List<Atendimento>;
      });
    } catch (e) {
      _erro('Falha ao carregar cliente: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Exibe mensagem de erro padronizada em snackbar vermelho.
  void _erro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(mensagem)),
    );
  }

  /// Exibe mensagem de sucesso padronizada em snackbar verde.
  void _sucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(mensagem)),
    );
  }

  /// Aciona resgate de fidelidade quando o cliente tem pontos suficientes.
  Future<void> _resgatarFidelidade() async {
    final cliente = _cliente;
    if (cliente == null || !cliente.temCorteGratis || cliente.id == null) return;
    try {
      await _service.resgatarFidelidade(cliente.id!);
      _sucesso('Fidelidade resgatada com sucesso');
      await _carregar();
    } catch (e) {
      _erro('Falha ao resgatar fidelidade: $e');
    }
  }

  /// Abre formulario de edicao e persiste alteracoes do cliente.
  Future<void> _editarCliente() async {
    final cliente = _cliente;
    if (cliente == null) return;
    final atualizado = await Navigator.push<Cliente>(
      context,
      MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: cliente)),
    );
    if (atualizado == null) return;

    try {
      await _service.update(atualizado);
      _sucesso('Cliente atualizado com sucesso');
      await _carregar();
    } catch (e) {
      _erro('Falha ao atualizar cliente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estado de carregamento da tela de detalhe.
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Estado sem cliente quando cadastro foi removido.
    if (_cliente == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cliente')),
      body: const Center(child: Text('Cliente não encontrado')),
      );
    }

    final cliente = _cliente!;
    final pontos = cliente.pontosFidelidade % AppConstants.cortesFidelidade;

    // Tela principal de detalhe com cards e historico.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Cliente'),
        actions: [IconButton(onPressed: _editarCliente, icon: const Icon(Icons.edit))],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card de dados cadastrais basicos.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente.nome,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.phone, size: 18), const SizedBox(width: 6), Text(cliente.telefone)]),
                    if (cliente.dataNascimento != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.cake_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text(AppFormatters.date(cliente.dataNascimento!)),
                        ],
                      ),
                    ],
                    if ((cliente.observacoes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(cliente.observacoes!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Card de estatisticas de consumo e recorrencia.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estatisticas',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _rowInfo('Total gasto', AppFormatters.currency(cliente.totalGasto)),
                    _rowInfo('Atendimentos', '${cliente.totalAtendimentos}'),
                    _rowInfo(
                      'Ultima visita',
                      cliente.ultimaVisita != null
                          ? AppFormatters.dateTime(cliente.ultimaVisita!)
                          : 'Sem registro',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Card do programa de fidelidade com barra e acao de resgate.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fidelidade',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${cliente.pontosFidelidade} pontos acumulados'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: pontos / AppConstants.cortesFidelidade,
                      minHeight: 8,
                      color: AppTheme.goldColor,
                    ),
                    const SizedBox(height: 6),
              Text('$pontos/${AppConstants.cortesFidelidade} para próximo brinde'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: cliente.temCorteGratis ? _resgatarFidelidade : null,
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('Resgatar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Lista de historico de atendimentos do cliente.
                  Text('Histórico de atendimentos',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_historico.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum atendimento encontrado para este cliente'),
                ),
              )
            else
              ..._historico.map(
                (a) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(AppFormatters.dateTime(a.data)),
                    subtitle: Text(
                      '${a.itens.map((e) => e.nome).join(', ').isEmpty ? 'Sem itens detalhados' : a.itens.map((e) => e.nome).join(', ')}\n${a.formaPagamento}',
                    ),
                    trailing: Text(
                      AppFormatters.currency(a.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Helper para renderizar linhas de informacao em cards de resumo.
  Widget _rowInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
