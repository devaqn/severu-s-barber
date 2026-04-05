import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/security_utils.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';
import 'criar_barbeiro_screen.dart';

class BarbeirosScreen extends StatefulWidget {
  const BarbeirosScreen({super.key});

  @override
  State<BarbeirosScreen> createState() => _BarbeirosScreenState();
}

class _BarbeirosScreenState extends State<BarbeirosScreen> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  List<Usuario> _barbeiros = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) setState(() => _loading = true);
    try {
      final barbeiros = await _authService.listarBarbeiros(apenasAtivos: false);
      if (!mounted) return;
      setState(() => _barbeiros = barbeiros);
    } catch (e) {
      if (!mounted) return;
      UiFeedback.showSnack(
        context,
        'Falha ao carregar barbeiros: $e',
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAtivo(Usuario usuario, bool ativo) async {
    try {
      await _authService.toggleAtivo(usuario.id, ativo);
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      UiFeedback.showSnack(
        context,
        'Falha ao atualizar status: $e',
        type: AppNoticeType.error,
      );
    }
  }

  Future<void> _abrirCriacao() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CriarBarbeiroScreen()),
    );
    if (created == true) {
      await _carregar();
    }
  }

  Future<void> _abrirEdicao(Usuario usuario) async {
    final nomeCtrl = TextEditingController(text: usuario.nome);
    final emailCtrl = TextEditingController(text: usuario.email);
    final telefoneCtrl = TextEditingController(text: usuario.telefone ?? '');
    final comissaoCtrl =
        TextEditingController(text: usuario.comissaoPercentual.toStringAsFixed(2));

    try {
      final updated = await showDialog<Usuario>(
        context: context,
        builder: (ctx) {
          final formKey = GlobalKey<FormState>();
          var ativoLocal = usuario.ativo;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text(
                  'Editar Barbeiro',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                content: SizedBox(
                  width: 420,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nomeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Informe o nome.';
                              }
                              try {
                                SecurityUtils.sanitizeName(v);
                              } catch (_) {
                                return 'Nome invalido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Informe o e-mail.';
                              }
                              try {
                                SecurityUtils.sanitizeEmail(v);
                              } catch (_) {
                                return 'E-mail invalido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: telefoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Telefone',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              try {
                                SecurityUtils.sanitizePhone(v);
                              } catch (_) {
                                return 'Telefone invalido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: comissaoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '% Comissao',
                              prefixIcon: Icon(Icons.percent),
                            ),
                            validator: (v) {
                              final valor =
                                  double.tryParse((v ?? '').replaceAll(',', '.'));
                              if (valor == null) return 'Informe um numero.';
                              if (valor < 0 || valor > 100) {
                                return 'Valor entre 0 e 100.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            value: ativoLocal,
                            onChanged: (v) =>
                                setDialogState(() => ativoLocal = v),
                            title: const Text('Ativo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final atualizado = usuario.copyWith(
                        nome: SecurityUtils.sanitizeName(nomeCtrl.text),
                        email: SecurityUtils.sanitizeEmail(emailCtrl.text),
                        telefone: telefoneCtrl.text.trim().isEmpty
                            ? null
                            : SecurityUtils.sanitizePhone(telefoneCtrl.text),
                        comissaoPercentual: double.parse(
                          comissaoCtrl.text.replaceAll(',', '.'),
                        ),
                        ativo: ativoLocal,
                      );
                      Navigator.pop(ctx, atualizado);
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (updated == null) return;
      await _authService.atualizarUsuario(updated);
      if (!mounted) return;
      UiFeedback.showSnack(
        context,
        'Barbeiro atualizado com sucesso.',
        type: AppNoticeType.success,
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      UiFeedback.showSnack(
        context,
        'Falha ao atualizar barbeiro: $e',
        type: AppNoticeType.error,
      );
    } finally {
      nomeCtrl.dispose();
      emailCtrl.dispose();
      telefoneCtrl.dispose();
      comissaoCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Barbeiros',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.barbeiros),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCriacao,
        backgroundColor: AppTheme.accentColor,
        icon: const Icon(Icons.person_add, color: AppTheme.textPrimary),
        label: Text(
          'Adicionar Barbeiro',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AppPageContainer(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _barbeiros.isEmpty
                ? AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'Nenhum barbeiro cadastrado',
                    subtitle: 'Adicione o primeiro barbeiro para iniciar a equipe.',
                    actionLabel: 'Adicionar Barbeiro',
                    onAction: _abrirCriacao,
                  )
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      itemCount: _barbeiros.length,
                      itemBuilder: (context, index) {
                        final usuario = _barbeiros[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            title: Text(
                              usuario.nome,
                              style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  usuario.email,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if ((usuario.telefone ?? '').isNotEmpty)
                                  Text(
                                    AppFormatters.phone(usuario.telefone!),
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                Text(
                                  'Comissao: ${usuario.comissaoPercentual.toStringAsFixed(2)}%',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.goldColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () => _abrirEdicao(usuario),
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppTheme.infoColor),
                                  tooltip: 'Editar',
                                ),
                                Transform.scale(
                                  scale: 0.9,
                                  child: Switch.adaptive(
                                    value: usuario.ativo,
                                    activeThumbColor: AppTheme.successColor,
                                    onChanged: (v) => _toggleAtivo(usuario, v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
