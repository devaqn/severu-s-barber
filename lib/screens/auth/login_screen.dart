import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/app_theme.dart';
import '../../utils/security_utils.dart';
import '../../widgets/ui_helpers.dart';
import 'cadastro_screen.dart';
import 'primeiro_login_screen.dart';
import 'recuperar_senha_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const bool _atalhoContaTesteDefine = bool.fromEnvironment(
    'ENABLE_FIREBASE_TEST_SHORTCUT',
    defaultValue: false,
  );
  static const String _contaTesteEmail = String.fromEnvironment(
    'FIREBASE_TEST_ADMIN_EMAIL',
    defaultValue: 'teste@severus.app',
  );
  static const String _contaTesteSenha = String.fromEnvironment(
    'FIREBASE_TEST_ADMIN_PASSWORD',
    defaultValue: 'Teste@123!',
  );

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _senhaVisivel = false;
  bool _podeCadastrarAdminPublicamente = false;
  bool _checandoCadastroPublico = true;

  bool get _mostrarAtalhoContaTeste => kDebugMode || _atalhoContaTesteDefine;

  @override
  void initState() {
    super.initState();
    _carregarDisponibilidadeCadastro();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final safeEmail = SecurityUtils.sanitizeEmail(_emailCtrl.text);
    _emailCtrl.text = safeEmail;

    final ctrl = context.read<AuthController>();
    final ok = await ctrl.login(safeEmail, _senhaCtrl.text);
    if (!ok && mounted) {
      UiFeedback.showSnack(
        context,
        ctrl.errorMsg ?? 'Falha ao autenticar. Verifique seus dados.',
        type: AppNoticeType.error,
      );
      return;
    }

    if (ok && mounted && (ctrl.usuario?.firstLogin ?? false)) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrimeiroLoginScreen()),
      );
    }
  }

  Future<void> _carregarDisponibilidadeCadastro() async {
    try {
      final ctrl = context.read<AuthController>();
      if (!ctrl.firebaseDisponivel) {
        if (!mounted) return;
        setState(() {
          _podeCadastrarAdminPublicamente = false;
          _checandoCadastroPublico = false;
        });
        return;
      }
      final pode = await ctrl.podeCadastrarAdminPublicamente();
      if (!mounted) return;
      setState(() {
        _podeCadastrarAdminPublicamente = pode;
        _checandoCadastroPublico = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _podeCadastrarAdminPublicamente = false;
        _checandoCadastroPublico = false;
      });
    }
  }

  Future<void> _entrarComContaTesteFirebase() async {
    final ctrl = context.read<AuthController>();
    final ok = await ctrl.entrarOuCriarContaTesteFirebase();
    if (ok || !mounted) return;

    UiFeedback.showSnack(
      context,
      ctrl.errorMsg ?? 'Nao foi possivel entrar com a conta de teste.',
      type: AppNoticeType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AuthController>();
    final mostrarAtalhoContaTeste =
        _mostrarAtalhoContaTeste || !ctrl.firebaseDisponivel;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: AppPageContainer(
          maxWidth: 460,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.accentColor,
                                AppTheme.accentDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentColor
                                    .withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.content_cut,
                            color: AppTheme.textPrimary,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Severus Barber',
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gestao profissional da barbearia',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  Text(
                    'Entrar',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Acesse sua conta para continuar.',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  ),
                  if (!ctrl.firebaseDisponivel) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
              'Firebase não configurado neste APK. '
                        'Use login de teste local para validar o app.',
                        style: GoogleFonts.inter(
                          color: AppTheme.warningColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o e-mail.';
                      }
                      try {
                        SecurityUtils.sanitizeEmail(value);
                      } catch (_) {
                  return 'E-mail inválido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _senhaCtrl,
                    obscureText: !_senhaVisivel,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _login(),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe a senha.';
                      }
                      if (value.length < 6) return 'Senha muito curta.';
                      if (value.length > 128) return 'Senha muito longa.';
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecuperarSenhaScreen(),
                        ),
                      ),
                      child: const Text(
                        'Esqueceu a senha?',
                        style: TextStyle(color: AppTheme.accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: ctrl.isLoading ? null : _login,
                      child: ctrl.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Entrar no sistema',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (mostrarAtalhoContaTeste) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: ctrl.isLoading
                            ? null
                            : _entrarComContaTesteFirebase,
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Entrar com conta de teste'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Teste Firebase: $_contaTesteEmail / $_contaTesteSenha',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_checandoCadastroPublico)
                    const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (!_checandoCadastroPublico &&
                      _podeCadastrarAdminPublicamente)
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Primeiro acesso? ',
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CadastroScreen(),
                              ),
                            ),
                            child: Text(
                              'Criar conta de administrador',
                              style: GoogleFonts.inter(
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
