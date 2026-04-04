import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/app_theme.dart';
import '../../utils/security_utils.dart';
import '../../widgets/ui_helpers.dart';

class RecuperarSenhaScreen extends StatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _enviado = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _recuperar() async {
    if (!_formKey.currentState!.validate()) return;

    final safeEmail = SecurityUtils.sanitizeEmail(_emailCtrl.text);
    _emailCtrl.text = safeEmail;

    final ctrl = context.read<AuthController>();
    final ok = await ctrl.recuperarSenha(safeEmail);
    if (!mounted) return;

    if (ok) {
      setState(() => _enviado = true);
      UiFeedback.showSnack(
        context,
        'E-mail de recuperação enviado.',
        type: AppNoticeType.success,
      );
      return;
    }

    UiFeedback.showSnack(
      context,
      ctrl.errorMsg ?? 'Não foi possível enviar o e-mail.',
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
          maxWidth: 480,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _enviado ? _buildSucesso() : _buildForm(ctrl),
        ),
      ),
    );
  }

  Widget _buildSucesso() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_read,
              color: AppTheme.successColor,
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              'E-mail enviado',
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifique sua caixa de entrada e siga as instruções para redefinir a senha.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar ao login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AuthController ctrl) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recuperar senha',
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Informe o e-mail da conta para receber o link de recuperação.',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _recuperar(),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o e-mail.';
                try {
                  SecurityUtils.sanitizeEmail(v);
                } catch (_) {
                  return 'E-mail inválido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: ctrl.isLoading ? null : _recuperar,
                child: ctrl.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Enviar e-mail',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
