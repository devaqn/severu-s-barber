import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/app_theme.dart';
import '../../utils/security_utils.dart';
import '../../widgets/ui_helpers.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();

  bool _senhaVisivel = false;
  bool _confirmacaoVisivel = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaSenhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    final safeNome = SecurityUtils.sanitizeName(_nomeCtrl.text);
    final safeEmail = SecurityUtils.sanitizeEmail(_emailCtrl.text);
    _nomeCtrl.text = safeNome;
    _emailCtrl.text = safeEmail;

    final ctrl = context.read<AuthController>();
    final ok = await ctrl.cadastrarAdmin(
      nome: safeNome,
      email: safeEmail,
      password: _senhaCtrl.text,
    );

    if (!mounted || ok) return;

    UiFeedback.showSnack(
      context,
      ctrl.errorMsg ?? 'N\u00E3o foi poss\u00EDvel concluir o cadastro.',
      type: AppNoticeType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: AppPageContainer(
          maxWidth: 520,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Criar Conta de Administrador',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configure o acesso inicial do dono da barbearia.',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nomeCtrl,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe o nome.';
                      }
                      try {
                        SecurityUtils.sanitizeName(v);
                      } catch (e) {
                        return e.toString();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username
                    ],
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe o e-mail.';
                      }
                      try {
                        SecurityUtils.sanitizeEmail(v);
                      } catch (_) {
                        return 'E-mail inv\u00E1lido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _senhaCtrl,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    obscureText: !_senhaVisivel,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppTheme.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                        icon: Icon(
                          _senhaVisivel
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a senha.';
                      try {
                        SecurityUtils.ensureStrongPassword(v);
                      } catch (e) {
                        return e.toString();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmaSenhaCtrl,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    obscureText: !_confirmacaoVisivel,
                    onFieldSubmitted: (_) => _cadastrar(),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      prefixIcon: const Icon(
                        Icons.lock_reset,
                        color: AppTheme.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _confirmacaoVisivel = !_confirmacaoVisivel,
                        ),
                        icon: Icon(
                          _confirmacaoVisivel
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirme a senha.';
                      if (v != _senhaCtrl.text) {
                        return 'As senhas n\u00E3o conferem.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.infoColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.infoColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esta conta ter\u00E1 acesso total ao sistema.',
                            style: GoogleFonts.inter(
                              color: AppTheme.infoColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: ctrl.isLoading ? null : _cadastrar,
                      child: ctrl.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Criar conta',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
