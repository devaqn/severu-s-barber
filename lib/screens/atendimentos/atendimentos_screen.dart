import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/atendimento_controller.dart';
import '../../models/atendimento.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';
import 'novo_atendimento_screen.dart';

class AtendimentosScreen extends StatefulWidget {
  const AtendimentosScreen({super.key});

  @override
  State<AtendimentosScreen> createState() => _AtendimentosScreenState();
}

class _AtendimentosScreenState extends State<AtendimentosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<Atendimento> _atendimentos = [];
  bool _loading = true;
  int _rangeDays = 30;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_disposed) return;
    setState(() => _loading = true);
    try {
      final fim = DateTime.now();
      final inicio = fim.subtract(Duration(days: _rangeDays));
      final ctrl = context.read<AtendimentoController>();
      final atendimentos = await ctrl.getPorPeriodo(inicio, fim);
      if (_disposed) return;
      _atendimentos = atendimentos;
      if (ctrl.errorMsg != null && mounted) {
        UiFeedback.showSnack(
          context,
          ctrl.errorMsg!,
          type: AppNoticeType.error,
        );
      }
    } catch (e) {
      if (mounted && !_disposed) {
        UiFeedback.showSnack(
          context,
          'Falha ao carregar atendimentos: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (!_disposed) setState(() => _loading = false);
    }
  }

  List<Atendimento> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _atendimentos;
    return _atendimentos.where((atendimento) {
      final cliente = atendimento.clienteNome.toLowerCase();
      final forma = atendimento.formaPagamento.toLowerCase();
      final itens =
          atendimento.itens.map((item) => item.nome.toLowerCase()).join(' ');
      return cliente.contains(query) ||
          forma.contains(query) ||
          itens.contains(query);
    }).toList(growable: false);
  }

  Color _corPagamento(String forma) {
    if (forma == AppConstants.pgDinheiro) return AppTheme.successColor;
    if (forma == AppConstants.pgPix) return AppTheme.infoColor;
    return AppTheme.warningDark;
  }

  void _abrirDetalhes(Atendimento atendimento) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Detalhes do atendimento',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Data: ${AppFormatters.dateTime(atendimento.data)}'),
                Text('Cliente: ${atendimento.clienteNome}'),
                Text('Pagamento: ${atendimento.formaPagamento}'),
                Text('Total: ${AppFormatters.currency(atendimento.total)}'),
                if ((atendimento.observacoes ?? '').isNotEmpty)
                  Text('Observações: ${atendimento.observacoes}'),
                const Divider(height: 24),
                Text(
                  'Itens',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (atendimento.itens.isEmpty)
                  const Text('Sem itens detalhados.')
                else
                  ...atendimento.itens.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.nome),
                      subtitle: Text(
                        '${item.quantidade} x '
                        '${AppFormatters.currency(item.precoUnitario)}',
                      ),
                      trailing: Text(AppFormatters.currency(item.subtotal)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Atendimentos',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.atendimentos),
      floatingActionButton: filtered.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.accentColor,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NovoAtendimentoScreen()),
                );
                await _carregar();
              },
              icon: const Icon(Icons.add, color: AppTheme.textPrimary),
              label: Text(
                'Novo atendimento',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AppPageContainer(
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('7 dias'),
                        selected: _rangeDays == 7,
                        onSelected: (_) async {
                          setState(() => _rangeDays = 7);
                          await _carregar();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('30 dias'),
                        selected: _rangeDays == 30,
                        onSelected: (_) async {
                          setState(() => _rangeDays = 30);
                          await _carregar();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('90 dias'),
                        selected: _rangeDays == 90,
                        onSelected: (_) async {
                          setState(() => _rangeDays = 90);
                          await _carregar();
                        },
                      ),
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar cliente, item ou pagamento',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? AppEmptyState(
                            icon: Icons.content_cut,
                            title: _searchCtrl.text.trim().isEmpty
                                ? 'Nenhum atendimento no período'
                                : 'Nenhum resultado para esta busca',
                            subtitle: _searchCtrl.text.trim().isEmpty
                                ? 'Registre um novo atendimento para começar.'
                                : 'Ajuste os filtros para encontrar atendimentos.',
                            actionLabel: _searchCtrl.text.trim().isEmpty
                                ? 'Novo atendimento'
                                : null,
                            onAction: _searchCtrl.text.trim().isEmpty
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NovoAtendimentoScreen(),
                                      ),
                                    );
                                    await _carregar();
                                  }
                                : null,
                          )
                        : RefreshIndicator(
                            onRefresh: _carregar,
                            child: ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final atendimento = filtered[index];
                                final itens = atendimento.itens
                                    .map((item) => item.nome)
                                    .join(', ');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor,
                                    borderRadius: BorderRadius.circular(16),
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
                                    onTap: () => _abrirDetalhes(atendimento),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.infoColor,
                                            AppTheme.infoDark
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    title: Text(
                                      atendimento.clienteNome,
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
                                          AppFormatters.dateTime(
                                              atendimento.data),
                                          style: GoogleFonts.inter(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          itens.isEmpty
                                              ? 'Sem itens detalhados'
                                              : itens,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Chip(
                                          label:
                                              Text(atendimento.formaPagamento),
                                          labelStyle: GoogleFonts.inter(
                                            color: AppTheme.textPrimary,
                                          ),
                                          backgroundColor: _corPagamento(
                                              atendimento.formaPagamento),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      AppFormatters.currency(atendimento.total),
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.successColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
