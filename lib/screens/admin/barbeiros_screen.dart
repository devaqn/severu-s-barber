import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String _apenasDigitos(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _mascararTelefone(String value) {
    final digits = _apenasDigitos(value);
    if (digits.isEmpty) return '';
    if (digits.length <= 2) return '($digits';
    if (digits.length <= 6) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2)}';
    }
    if (digits.length <= 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
  }

  void _aplicarMascaraTelefone(TextEditingController ctrl, String value) {
    final digits = _apenasDigitos(value);
    final limitado = digits.length > 11 ? digits.substring(0, 11) : digits;
    final masked = _mascararTelefone(limitado);
    if (masked == ctrl.text) return;
    ctrl.value = TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

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
    final telefoneCtrl = TextEditingController(
      text: (usuario.telefone ?? '').isEmpty
          ? ''
          : AppFormatters.phone(usuario.telefone!),
    );
    final comissaoCtrl = TextEditingController(
      text: usuario.comissaoPercentual.toStringAsFixed(2),
    );

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
                  'Editar barbeiro',
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
                                return 'Nome inválido.';
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
                                return 'E-mail inválido.';
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
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            onChanged: (v) =>
                                _aplicarMascaraTelefone(telefoneCtrl, v),
                            validator: (v) {
                              final digits = _apenasDigitos(v ?? '');
                              if (digits.isEmpty) return null;
                              if (digits.length < 10) {
                                return 'Informe ao menos 10 dígitos.';
                              }
                              if (digits.length > 11) {
                                return 'Máximo de 11 dígitos.';
                              }
                              try {
                                SecurityUtils.sanitizePhone(v ?? '');
                              } catch (_) {
                                return 'Telefone inválido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: comissaoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: '% Comissão',
                              prefixIcon: Icon(Icons.percent),
                            ),
                            validator: (v) {
                              final valor = double.tryParse(
                                  (v ?? '').replaceAll(',', '.'));
                              if (valor == null) return 'Informe um número.';
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

  Future<void> _excluirBarbeiro(Usuario usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir barbeiro'),
        content: Text(
          'Deseja excluir ${usuario.nome}?\n\nEssa ação remove o perfil do barbeiro do sistema.',
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

    if (confirmar != true) return;
    try {
      await _authService.excluirBarbeiro(usuario.id);
      if (!mounted) return;
      UiFeedback.showSnack(
        context,
        'Barbeiro excluído com sucesso.',
        type: AppNoticeType.success,
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      UiFeedback.showSnack(
        context,
        'Falha ao excluir barbeiro: $e',
        type: AppNoticeType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textPrimary,
        title: Text(
          'Barbeiros',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _carregar,
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.barbeiros),
      floatingActionButton: !_loading && _barbeiros.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _abrirCriacao,
              backgroundColor: Colors.black,
              icon: const Icon(Icons.person_add, color: AppTheme.textPrimary),
              label: Text(
                'Adicionar Barbeiro',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: Container(
        color: AppTheme.primaryColor,
        child: AppPageContainer(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _barbeiros.isEmpty
                  ? AppEmptyState(
                      icon: Icons.people_outline,
                      title: 'Nenhum barbeiro cadastrado',
                      subtitle:
                          'Adicione o primeiro barbeiro para iniciar a equipe.',
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
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (usuario.ativo
                                        ? AppTheme.accentColor
                                        : Colors.grey)
                                    .withValues(alpha: 0.28),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
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
                                  const SizedBox(height: 6),
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
                                    'Comissão: ${usuario.comissaoPercentual.toStringAsFixed(2)}%',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.goldColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: SizedBox(
                                width: 108,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              _abrirEdicao(usuario),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: AppTheme.infoColor,
                                          ),
                                          tooltip: 'Editar',
                                          constraints: const BoxConstraints(),
                                          visualDensity: const VisualDensity(
                                            horizontal: -2,
                                            vertical: -2,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          onPressed: () =>
                                              _excluirBarbeiro(usuario),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppTheme.errorColor,
                                          ),
                                          tooltip: 'Excluir',
                                          constraints: const BoxConstraints(),
                                          visualDensity: const VisualDensity(
                                            horizontal: -2,
                                            vertical: -2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Transform.scale(
                                      scale: 0.88,
                                      child: Switch.adaptive(
                                        value: usuario.ativo,
                                        activeThumbColor: AppTheme.accentColor,
                                        onChanged: (v) =>
                                            _toggleAtivo(usuario, v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
