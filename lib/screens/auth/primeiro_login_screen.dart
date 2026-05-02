import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../utils/security_utils.dart';
import '../../widgets/ui_helpers.dart';

class PrimeiroLoginScreen extends StatefulWidget {
  const PrimeiroLoginScreen({super.key});

  @override
  State<PrimeiroLoginScreen> createState() => _PrimeiroLoginScreenState();
}

class _PrimeiroLoginScreenState extends State<PrimeiroLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _visivel = false;
  bool _salvando = false;

  @override
  void dispose() {
    _senhaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();

    setState(() => _salvando = true);
    try {
      final ok = await authController.concluirPrimeiroLoginComNovaSenha(
        _senhaCtrl.text,
      );
      if (!ok) {
        if (!mounted) return;
        UiFeedback.showSnack(
          context,
          authController.errorMsg ?? 'Falha ao atualizar senha.',
          type: AppNoticeType.error,
        );
        return;
      }

      if (!mounted) return;

      UiFeedback.showSnack(
        context,
        'Senha atualizada com sucesso.',
        type: AppNoticeType.success,
      );

      final rota = authController.isAdmin
          ? AppRoutes.dashboardAdmin
          : AppRoutes.dashboardBarbeiro;
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, rota, (route) => false);
    } catch (e) {
      if (!mounted) return;
      UiFeedback.showSnack(
        context,
        'Falha ao atualizar senha: $e',
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Primeiro Acesso',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: AppPageContainer(
          maxWidth: 520,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crie sua nova senha',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por seguranca, altere a senha temporaria antes de acessar o sistema.',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: !_visivel,
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _visivel = !_visivel),
                      icon: Icon(
                          _visivel ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a nova senha.';
                    }
                    try {
                      SecurityUtils.ensureStrongPassword(value);
                    } catch (e) {
                      return e.toString();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmarCtrl,
                  obscureText: !_visivel,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nova senha',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirme a senha.';
                    }
                    if (value != _senhaCtrl.text) {
                      return 'As senhas não conferem.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    'Salvar nova senha',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
