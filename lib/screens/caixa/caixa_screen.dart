// ============================================================
// caixa_screen.dart
// Controle de abertura e fechamento de caixa diario.
// Mostra resumo por forma de pagamento ao fechar.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/caixa.dart';
import '../../services/financeiro_service.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_drawer.dart';

class CaixaScreen extends StatefulWidget {
  const CaixaScreen({super.key});

  @override
  State<CaixaScreen> createState() => _CaixaScreenState();
}

class _CaixaScreenState extends State<CaixaScreen> {
  final FinanceiroService _service = FinanceiroService();

  Caixa? _caixaAberto;
  List<Caixa> _historico = [];
  Map<String, double> _pagamentosHoje = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getCaixaAberto(),
        _service.getCaixas(limit: 20),
      ]);

      final aberto = results[0] as Caixa?;
      final historico = results[1] as List<Caixa>;

      Map<String, double> pagamentos = {};
      if (aberto != null) {
        pagamentos = await _service.getFaturamentoPorPagamento(
          aberto.dataAbertura,
          DateTime.now(),
        );
      }

      if (mounted) {
        setState(() {
          _caixaAberto = aberto;
          _historico = historico;
          _pagamentosHoje = pagamentos;
        });
      }
    } catch (e) {
      _erro('Falha ao carregar caixa: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirCaixa() async {
    final ctrl = TextEditingController(text: '0,00');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o valor inicial em caixa:'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Valor inicial (R\$)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir Caixa')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final valor = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
        await _service.abrirCaixa(valorInicial: valor);
        await _carregar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.successColor,
              content: Text('Caixa aberto com sucesso!'),
            ),
          );
        }
      } catch (e) {
        _erro('Falha ao abrir caixa: $e');
      }
    }
  }

  Future<void> _fecharCaixa() async {
    if (_caixaAberto == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fechar Caixa'),
        content: const Text(
          'Deseja fechar o caixa agora?\n\nO resumo por forma de pagamento sera calculado automaticamente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Fechar Caixa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _service.fecharCaixa(_caixaAberto!.id!);
        await _carregar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.successColor,
              content: Text('Caixa fechado com sucesso!'),
            ),
          );
        }
      } catch (e) {
        _erro('Falha ao fechar caixa: $e');
      }
    }
  }

  Future<void> _sangria() async {
    if (_caixaAberto == null) return;
    final ctrl = TextEditingController();
    final obsCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sangria de Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o valor retirado do caixa:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixIcon: Icon(Icons.arrow_downward),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Confirmar Sangria'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final valor = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
        await _service.sangria(
          caixaId: _caixaAberto!.id!,
          valor: valor,
          observacao: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        );
        await _carregar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.successColor,
              content: Text('Sangria de R\$ ${valor.toStringAsFixed(2)} registrada.'),
            ),
          );
        }
      } catch (e) {
        _erro('Falha na sangria: $e');
      }
    }
  }

  Future<void> _reforco() async {
    if (_caixaAberto == null) return;
    final ctrl = TextEditingController();
    final obsCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reforço de Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o valor adicionado ao caixa:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixIcon: Icon(Icons.arrow_upward),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Reforço'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final valor = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
        await _service.reforco(
          caixaId: _caixaAberto!.id!,
          valor: valor,
          observacao: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        );
        await _carregar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.successColor,
              content: Text('Reforço de R\$ ${valor.toStringAsFixed(2)} registrado.'),
            ),
          );
        }
      } catch (e) {
        _erro('Falha no reforço: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedItem: AppDrawer.caixa),
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Controle de Caixa',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusCaixa(),
                  const SizedBox(height: 24),
                  if (_historico.isNotEmpty) _buildHistorico(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCaixa() {
    if (_caixaAberto != null) {
      // Caixa aberto com cards de totais por forma de pagamento.
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.lock_open, size: 48, color: AppTheme.successColor),
              const SizedBox(height: 12),
              Text(
                'CAIXA ABERTO',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(height: 8),
              Text('Aberto em: ${AppFormatters.dateTime(_caixaAberto!.dataAbertura)}'),
              const SizedBox(height: 4),
              Text(
                'Valor inicial: ${AppFormatters.currency(_caixaAberto!.valorInicial)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              _pagamentoCard(
                titulo: AppConstants.pgDinheiro,
                valor: _pagamentosHoje[AppConstants.pgDinheiro] ?? 0,
                icone: Icons.payments,
                colors: const [AppTheme.successColor, AppTheme.successDark],
              ),
              _pagamentoCard(
                titulo: AppConstants.pgPix,
                valor: _pagamentosHoje[AppConstants.pgPix] ?? 0,
                icone: Icons.qr_code,
                colors: const [AppTheme.cyanColor, AppTheme.successColor],
              ),
              _pagamentoCard(
                titulo: AppConstants.pgCredito,
                valor: _pagamentosHoje[AppConstants.pgCredito] ?? 0,
                icone: Icons.credit_card,
                colors: const [AppTheme.purpleStart, AppTheme.purpleEnd],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sangria,
                      icon: const Icon(Icons.arrow_downward, color: AppTheme.errorColor),
                      label: const Text('Sangria', style: TextStyle(color: AppTheme.errorColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reforco,
                      icon: const Icon(Icons.arrow_upward, color: AppTheme.successColor),
                      label: const Text('Reforço', style: TextStyle(color: AppTheme.successColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.successColor),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _fecharCaixa,
                  icon: const Icon(Icons.lock),
                  label: const Text('Fechar Caixa'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Caixa fechado.
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.lock, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'CAIXA FECHADO',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Abra o caixa para iniciar as operacoes do dia.',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _abrirCaixa,
                icon: const Icon(Icons.lock_open),
                label: const Text('Abrir Caixa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorico() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historico de Caixas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._historico.map((c) {
          // Parse resumo de pagamentos do JSON.
          Map<String, dynamic>? resumo;
          if (c.resumoPagamentos != null) {
            try {
              resumo = jsonDecode(c.resumoPagamentos!) as Map<String, dynamic>;
            } catch (_) {}
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: c.isAberto
                    ? AppTheme.successColor.withValues(alpha: 0.2)
                    : AppTheme.textSecondary.withValues(alpha: 0.2),
                child: Icon(
                  c.isAberto ? Icons.lock_open : Icons.lock,
                  color: c.isAberto ? AppTheme.successColor : AppTheme.textSecondary,
                ),
              ),
              title: Text(AppFormatters.date(c.dataAbertura)),
              subtitle: Text(c.isAberto
                  ? 'Em aberto'
                  : 'Fechado em ${c.dataFechamento != null ? AppFormatters.time(c.dataFechamento!) : ''}'),
              trailing: c.valorFinal != null
                  ? Text(
                      AppFormatters.currency(c.valorFinal!),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                    )
                  : null,
              children: [
                if (resumo != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text(
                          'Resumo por pagamento:',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _pagamentoCard(
                          titulo: AppConstants.pgDinheiro,
                          valor: (resumo[AppConstants.pgDinheiro] as num?)?.toDouble() ?? 0,
                          icone: Icons.payments,
                          colors: const [AppTheme.successColor, AppTheme.successDark],
                        ),
                        _pagamentoCard(
                          titulo: AppConstants.pgPix,
                          valor: (resumo[AppConstants.pgPix] as num?)?.toDouble() ?? 0,
                          icone: Icons.qr_code,
                          colors: const [AppTheme.cyanColor, AppTheme.successColor],
                        ),
                        _pagamentoCard(
                          titulo: AppConstants.pgCredito,
                          valor: (resumo[AppConstants.pgCredito] as num?)?.toDouble() ?? 0,
                          icone: Icons.credit_card,
                          colors: const [AppTheme.purpleStart, AppTheme.purpleEnd],
                        ),
                        if (c.valorInicial > 0) ...[
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Valor inicial:'),
                              Text(AppFormatters.currency(c.valorInicial)),
                            ],
                          ),
                        ],
                        if (c.valorFinal != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total em caixa:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                AppFormatters.currency(c.valorFinal!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Card visual de resumo por forma de pagamento.
  Widget _pagamentoCard({
    required String titulo,
    required double valor,
    required IconData icone,
    required List<Color> colors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icone, color: AppTheme.textPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            AppFormatters.currency(valor),
            style: GoogleFonts.poppins(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

