import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/app_theme.dart';
import '../../utils/security_utils.dart';
import '../../widgets/ui_helpers.dart';

class CriarBarbeiroScreen extends StatefulWidget {
  const CriarBarbeiroScreen({super.key});

  @override
  State<CriarBarbeiroScreen> createState() => _CriarBarbeiroScreenState();
}

class _CriarBarbeiroScreenState extends State<CriarBarbeiroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _comissaoCtrl = TextEditingController(text: '50');
  bool _senhaVisivel = false;

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

  void _onTelefoneChanged(String value) {
    final digits = _apenasDigitos(value);
    final limitado = digits.length > 11 ? digits.substring(0, 11) : digits;
    final masked = _mascararTelefone(limitado);

    if (masked == _telefoneCtrl.text) return;
    _telefoneCtrl.value = TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    _comissaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    if (!_formKey.currentState!.validate()) return;

    final comissao =
        double.tryParse(_comissaoCtrl.text.replaceAll(',', '.')) ?? -1;
    if (comissao < 0 || comissao > 100) {
      UiFeedback.showSnack(
        context,
        'Comissao deve estar entre 0% e 100%.',
        type: AppNoticeType.error,
      );
      return;
    }

    final safeNome = SecurityUtils.sanitizeName(_nomeCtrl.text);
    final safeEmail = SecurityUtils.sanitizeEmail(_emailCtrl.text);
    final safeTelefone = _telefoneCtrl.text.trim().isEmpty
        ? null
        : SecurityUtils.sanitizePhone(_telefoneCtrl.text);

    final ctrl = context.read<AuthController>();
    final ok = await ctrl.cadastrarBarbeiro(
      nome: safeNome,
      email: safeEmail,
      password: _senhaCtrl.text,
      telefone: safeTelefone,
      comissaoPercentual: comissao,
      firstLogin: true,
    );

    if (!mounted) return;

    if (!ok) {
      UiFeedback.showSnack(
        context,
        ctrl.errorMsg ?? 'Falha ao criar barbeiro.',
        type: AppNoticeType.error,
      );
      return;
    }

    UiFeedback.showSnack(
      context,
      'Barbeiro criado com sucesso.',
      type: AppNoticeType.success,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Adicionar Barbeiro',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nomeCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefoneCtrl,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: _onTelefoneChanged,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: '(11) 99999-9999',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final digits = _apenasDigitos(v ?? '');
                    if (digits.isEmpty) return null;
                    if (digits.length < 10) {
                      return 'Informe ao menos 10 digitos.';
                    }
                    if (digits.length > 11) {
                      return 'Maximo de 11 digitos.';
                    }
                    try {
                      SecurityUtils.sanitizePhone(v ?? '');
                    } catch (_) {
                                return 'Telefone inválido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _senhaCtrl,
                  textInputAction: TextInputAction.next,
                  obscureText: !_senhaVisivel,
                  decoration: InputDecoration(
                    labelText: 'Senha temporaria',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _senhaVisivel = !_senhaVisivel),
                      icon: Icon(
                        _senhaVisivel ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Informe a senha temporaria.';
                    }
                    try {
                      SecurityUtils.ensureStrongPassword(v);
                    } catch (e) {
                      return e.toString().replaceFirst('Exception: ', '');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _comissaoCtrl,
                  textInputAction: TextInputAction.done,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '% Comissao',
                    prefixIcon: Icon(Icons.percent),
                  ),
                  validator: (v) {
                    final valor =
                        double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (valor == null) return 'Informe um numero valido.';
                    if (valor < 0 || valor > 100) {
                      return 'Valor deve estar entre 0 e 100.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'O barbeiro sera criado com status ativo e firstLogin ligado para trocar a senha no primeiro acesso.',
                    style: GoogleFonts.inter(
                      color: AppTheme.infoColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: ctrl.isLoading ? null : _criar,
                    icon: ctrl.isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(
                      'Criar Barbeiro',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
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
