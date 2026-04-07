import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/servico.dart';
import '../../services/servico_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/security_utils.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';

class ServicosScreen extends StatefulWidget {
  const ServicosScreen({super.key});

  @override
  State<ServicosScreen> createState() => _ServicosScreenState();
}

class _ServicosScreenState extends State<ServicosScreen> {
  final ServicoService _service = ServicoService();

  List<Servico> _servicos = [];
  bool _loading = true;
  bool _apenasAtivos = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      _servicos = await _service.getAll(apenasAtivos: _apenasAtivos);
    } catch (e) {
      _showSnack('Falha ao carregar serviços: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String mensagem, {bool isError = false}) {
    final background = isError ? AppTheme.errorColor : AppTheme.accentColor;
    final foreground = isError ? AppTheme.textPrimary : AppTheme.primaryColor;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        content: Text(
          mensagem,
          style:
              GoogleFonts.inter(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _abrirFormulario({Servico? servico}) async {
    final nomeCtrl = TextEditingController(text: servico?.nome ?? '');
    final precoCtrl = TextEditingController(
      text: servico != null ? servico.preco.toStringAsFixed(2) : '',
    );
    final duracaoCtrl = TextEditingController(
      text: servico?.duracaoMinutos.toString() ?? '30',
    );
    final comissaoCtrl = TextEditingController(
      text: (((servico?.comissaoPercentual ?? 0.5) * 100).toStringAsFixed(0)),
    );

    bool ativo = servico?.ativo ?? true;
    bool salvando = false;
    final formKey = GlobalKey<FormState>();

    final shouldReload = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> salvar() async {
              if (!formKey.currentState!.validate() || salvando) return;
              setModalState(() => salvando = true);
              try {
                final preco =
                    double.parse(precoCtrl.text.trim().replaceAll(',', '.'));
                final duracao = int.parse(duracaoCtrl.text.trim());
                final comissaoPercent =
                    double.parse(comissaoCtrl.text.trim().replaceAll(',', '.'));
                final comissaoDecimal = comissaoPercent / 100;

                final payload = Servico(
                  id: servico?.id,
                  nome: nomeCtrl.text.trim(),
                  preco: preco,
                  duracaoMinutos: duracao,
                  comissaoPercentual: comissaoDecimal,
                  ativo: ativo,
                );

                if (servico == null) {
                  await _service.insert(payload);
                } else {
                  await _service.update(payload);
                }

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
                if (!mounted) return;
                _showSnack(
                  servico == null
                      ? 'Serviço criado com sucesso'
                      : 'Serviço atualizado',
                );
              } catch (e) {
                if (!mounted) return;
                _showSnack('Falha ao salvar serviço: $e', isError: true);
              } finally {
                if (ctx.mounted) {
                  setModalState(() => salvando = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        servico == null ? 'Novo serviço' : 'Editar serviço',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome *'),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe o nome do serviço.';
                          }
                          try {
                            SecurityUtils.sanitizeName(v,
                                fieldName: 'Nome do serviço');
                          } catch (_) {
                            return 'Nome do serviço inválido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: precoCtrl,
                        decoration: const InputDecoration(labelText: 'Preço *'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final n = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'));
                          if (n == null || n <= 0) {
                            return 'Informe um preço maior que zero.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: duracaoCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Duração (min) *'),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) {
                            return 'Informe uma duração válida.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: comissaoCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Comissão (%) *'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        validator: (v) {
                          final n = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'));
                          if (n == null || n < 0 || n > 100) {
                            return 'Comissão deve estar entre 0 e 100.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: ativo,
                        activeThumbColor: AppTheme.accentColor,
                        onChanged: (v) => setModalState(() => ativo = v),
                        title: Text(
                          ativo ? 'Serviço ativo' : 'Serviço inativo',
                          style: GoogleFonts.inter(color: AppTheme.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: salvando ? null : salvar,
                          child: salvando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldReload == true) {
      await _carregar();
    }
  }

  Future<void> _alternarStatus(Servico servico, bool ativo) async {
    try {
      await _service.update(servico.copyWith(ativo: ativo));
      if (!mounted) return;
      _showSnack(ativo ? 'Serviço ativado.' : 'Serviço inativado.');
      await _carregar();
    } catch (e) {
      _showSnack('Falha ao alterar status: $e', isError: true);
    }
  }

  Future<void> _confirmarExclusao(Servico servico) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Excluir serviço',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Deseja inativar o serviço "${servico.nome}"?\n'
          'Ele não aparecerá mais nas listas, mas o histórico será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || servico.id == null) return;
    try {
      await _service.delete(servico.id!);
      if (!mounted) return;
      _showSnack('Serviço excluído');
      await _carregar();
    } catch (e) {
      _showSnack('Falha ao excluir serviço: $e', isError: true);
    }
  }

  Widget _buildServicoCard(Servico servico) {
    final leadingColor =
        servico.ativo ? AppTheme.accentColor : Colors.grey.shade500;
    final nome =
        servico.nome.trim().isEmpty ? 'Serviço sem nome' : servico.nome.trim();

    return Dismissible(
      key: ValueKey('servico_${servico.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmarExclusao(servico);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 78,
              decoration: BoxDecoration(
                color: leadingColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _abrirFormulario(servico: servico),
                        icon: const Icon(Icons.edit_outlined,
                            color: AppTheme.accentColor),
                        tooltip: 'Editar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppFormatters.duration(servico.duracaoMinutos)} • Comissão ${(servico.comissaoPercentual * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppFormatters.currency(servico.preco),
                    style: GoogleFonts.poppins(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch.adaptive(
                  value: servico.ativo,
                  activeThumbColor: AppTheme.accentColor,
                  onChanged: (v) => _alternarStatus(servico, v),
                ),
                Text(
                  servico.ativo ? 'Ativo' : 'Inativo',
                  style: GoogleFonts.inter(
                    color: servico.ativo
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Serviços',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          Row(
            children: [
              Text(
                'Mostrar apenas ativos',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              Switch.adaptive(
                value: _apenasAtivos,
                activeThumbColor: AppTheme.accentColor,
                onChanged: (v) {
                  setState(() => _apenasAtivos = v);
                  _carregar();
                },
              ),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.servicos),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add, color: AppTheme.primaryColor),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentColor))
          : AppPageContainer(
              child: _servicos.isEmpty
                  ? AppEmptyState(
                      icon: Icons.content_cut_outlined,
                      title: 'Nenhum serviço cadastrado',
                      subtitle:
                          'Cadastre um novo serviço para começar os atendimentos.',
                      actionLabel: 'Novo serviço',
                      onAction: () => _abrirFormulario(),
                    )
                  : RefreshIndicator(
                      color: AppTheme.accentColor,
                      onRefresh: _carregar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
                        itemCount: _servicos.length,
                        itemBuilder: (context, index) {
                          return _buildServicoCard(_servicos[index]);
                        },
                      ),
                    ),
            ),
    );
  }
}
