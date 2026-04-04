// ============================================================
// servicos_screen.dart
// Tela de gestao de servicos com lista, filtro e formulario modal.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/servico.dart';
import '../../services/servico_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';

/// Tela para gerenciamento de servicos ofertados pela barbearia.
class ServicosScreen extends StatefulWidget {
  /// Construtor padrao da tela de servicos.
  const ServicosScreen({super.key});

  @override
  State<ServicosScreen> createState() => _ServicosScreenState();
}

/// Estado da tela de servicos com CRUD e filtro de ativos.
class _ServicosScreenState extends State<ServicosScreen> {
  // Servico de dados para operacoes com servicos.
  final ServicoService _service = ServicoService();

  // Lista total exibida na tela.
  List<Servico> _servicos = [];

  // Flag de carregamento para feedback visual.
  bool _loading = true;

  // Toggle para exibir apenas ativos ou todos.
  bool _apenasAtivos = true;

  @override
  void initState() {
    super.initState();
    // Carregamento inicial da lista de servicos.
    _carregar();
  }

  /// Carrega servicos do banco de acordo com filtro ativo.
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      _servicos = await _service.getAll(apenasAtivos: _apenasAtivos);
    } catch (e) {
      _erro('Falha ao carregar servicos: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Snackbar de erro padrao em fundo vermelho.
  void _erro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(mensagem)),
    );
  }

  /// Snackbar de sucesso padrao em fundo verde.
  void _sucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(mensagem)),
    );
  }

  /// Abre modal de criacao/edicao e persiste os dados enviados.
  Future<void> _abrirModal({Servico? servico}) async {
    // Controllers locais do formulario de modal bottom sheet.
    final nomeCtrl = TextEditingController(text: servico?.nome ?? '');
    final precoCtrl = TextEditingController(
      text: servico != null ? servico.preco.toStringAsFixed(2) : '',
    );
    final duracaoCtrl = TextEditingController(
      text: servico?.duracaoMinutos.toString() ?? '30',
    );
    var ativo = servico?.ativo ?? true;

    // Exibe modal com formulario de servico.
    final result = await showModalBottomSheet<Servico>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      servico == null ? 'Novo Servico' : 'Editar Servico',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: precoCtrl,
                      decoration: const InputDecoration(labelText: 'Preco *'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Informe um preco valido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: duracaoCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Duracao (min) *'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Informe duracao valida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: ativo,
                      activeThumbColor: AppTheme.accentColor,
                      onChanged: (v) => setModalState(() => ativo = v),
                      title: Text(
                        'Ativo',
                        style: GoogleFonts.inter(color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final preco =
                              double.parse(precoCtrl.text.replaceAll(',', '.'));
                          final duracao = int.parse(duracaoCtrl.text);
                          Navigator.pop(
                            ctx,
                            Servico(
                              id: servico?.id,
                              nome: nomeCtrl.text.trim(),
                              preco: preco,
                              duracaoMinutos: duracao,
                              ativo: ativo,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    // Sai se modal foi fechado sem salvar.
    if (result == null) return;

    try {
      // Persiste insercao ou atualizacao conforme id.
      if (result.id == null) {
        await _service.insert(result);
        _sucesso('Servico criado com sucesso');
      } else {
        await _service.update(result);
        _sucesso('Servico atualizado com sucesso');
      }
      await _carregar();
    } catch (e) {
      _erro('Falha ao salvar servico: $e');
    }
  }

  /// Alterna status ativo/inativo preservando historico.
  Future<void> _toggleAtivo(Servico servico) async {
    try {
      if (servico.ativo) {
        await _service.delete(servico.id!);
        _sucesso('Servico desativado');
      } else {
        await _service.update(servico.copyWith(ativo: true));
        _sucesso('Servico ativado');
      }
      await _carregar();
    } catch (e) {
      _erro('Falha ao alterar status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela principal de servicos com drawer e lista.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Servicos',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Row(
            children: [
              Text('Ativos', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              Switch(
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
        backgroundColor: AppTheme.accentColor,
        onPressed: () => _abrirModal(),
        child: const Icon(Icons.add, color: AppTheme.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _servicos.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum servico cadastrado',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _servicos.length,
                    itemBuilder: (context, index) {
                      final s = _servicos[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Slidable(
                          key: ValueKey(s.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                onPressed: (_) => _abrirModal(servico: s),
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
                                onPressed: (_) => _toggleAtivo(s),
                                icon: s.ativo ? Icons.toggle_off : Icons.toggle_on,
                                label: s.ativo ? 'Desativar' : 'Ativar',
                                backgroundColor:
                                    s.ativo ? AppTheme.errorColor : AppTheme.successColor,
                                foregroundColor: AppTheme.textPrimary,
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
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
                                    colors: [AppTheme.warningColor, AppTheme.warningDark],
                                  ),
                                ),
                                child: const Icon(Icons.content_cut, color: AppTheme.textPrimary),
                              ),
                              title: Text(
                                s.nome,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Duracao: ${AppFormatters.duration(s.duracaoMinutos)}',
                                style: GoogleFonts.inter(color: AppTheme.textSecondary),
                              ),
                              trailing: Text(
                                AppFormatters.currency(s.preco),
                                style: GoogleFonts.poppins(
                                  color: AppTheme.successColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}


