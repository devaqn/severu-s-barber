// ============================================================
// cliente_form_screen.dart
// Formulario para criacao e edicao de clientes.
// ============================================================

import 'package:flutter/material.dart';
import '../../models/cliente.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/security_utils.dart';

/// Tela de formulario para novo cliente ou edicao de cadastro existente.
class ClienteFormScreen extends StatefulWidget {
  /// Cliente opcional para modo de edicao.
  final Cliente? cliente;

  /// Construtor padrao do formulario.
  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

/// Estado local do formulario de cliente com validacao e mascaramento basico.
class _ClienteFormScreenState extends State<ClienteFormScreen> {
  // Chave do formulario para validacao de campos.
  final _formKey = GlobalKey<FormState>();

  // Controllers dos campos editaveis.
  final _nomeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  DateTime? _dataNascimento;

  // Flag para diferenciar titulo e comportamento de salvar.
  bool get _edicao => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    // Preenche campos quando a tela recebe um cliente existente.
    if (_edicao) {
      _nomeCtrl.text = widget.cliente!.nome;
      _telefoneCtrl.text = widget.cliente!.telefone;
      _obsCtrl.text = widget.cliente!.observacoes ?? '';
      _dataNascimento = widget.cliente!.dataNascimento;
    }
  }

  @override
  void dispose() {
    // Libera recursos dos controllers do formulario.
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  /// Aplica mascara simples de telefone no formato (XX) XXXXX-XXXX.
  String _mascararTelefone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) return '($digits';
    if (digits.length <= 7) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2)}';
    }
    if (digits.length <= 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7, 11)}';
  }

  /// Valida e devolve o objeto cliente para a tela anterior salvar.
  void _salvar() {
    // Interrompe caso o formulario tenha campos invalidos.
    if (!_formKey.currentState!.validate()) return;

    final safeNome = SecurityUtils.sanitizeName(
      _nomeCtrl.text,
      fieldName: 'Nome do cliente',
    );
    final safeTelefone = SecurityUtils.sanitizePhone(_telefoneCtrl.text);
    final safeObs = SecurityUtils.sanitizeOptionalText(
      _obsCtrl.text,
      maxLength: 500,
      allowNewLines: true,
    );

    final now = DateTime.now();
    final base = widget.cliente;

    // Monta payload final preservando campos historicos quando em edicao.
    final cliente = Cliente(
      id: base?.id,
      nome: safeNome,
      telefone: safeTelefone,
      observacoes: safeObs,
      dataNascimento: _dataNascimento,
      totalGasto: base?.totalGasto ?? 0,
      ultimaVisita: base?.ultimaVisita,
      pontosFidelidade: base?.pontosFidelidade ?? 0,
      totalAtendimentos: base?.totalAtendimentos ?? 0,
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );

    // Fecha tela retornando cliente validado para persistencia externa.
    Navigator.pop(context, cliente);
  }

  Future<void> _selecionarDataNascimento() async {
    final hoje = DateTime.now();
    final inicial = _dataNascimento ?? DateTime(hoje.year - 25, hoje.month, 1);
    final selecionada = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoje) ? hoje : inicial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      locale: const Locale('pt', 'BR'),
      helpText: 'Data de nascimento',
    );
    if (selecionada == null) return;
    setState(() {
      _dataNascimento = DateTime(
        selecionada.year,
        selecionada.month,
        selecionada.day,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Estrutura principal do formulario de cliente.
    return Scaffold(
      appBar: AppBar(
        title: Text(_edicao ? 'Editar Cliente' : 'Novo Cliente'),
        actions: [
          IconButton(onPressed: _salvar, icon: const Icon(Icons.check)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campo obrigatorio de nome completo.
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o nome';
                try {
                  SecurityUtils.sanitizeName(v, fieldName: 'Nome');
                } catch (_) {
                  return 'Nome invalido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Campo obrigatorio de telefone com mascara visual.
            TextFormField(
              controller: _telefoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Telefone *',
                prefixIcon: Icon(Icons.phone),
                hintText: '(11) 99999-9999',
              ),
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                final masked = _mascararTelefone(value);
                if (masked != _telefoneCtrl.text) {
                  _telefoneCtrl.value = TextEditingValue(
                    text: masked,
                    selection: TextSelection.collapsed(offset: masked.length),
                  );
                }
              },
              validator: (v) {
                try {
                  SecurityUtils.sanitizePhone(v ?? '');
                } catch (_) {
                  return 'Telefone invalido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Campo opcional de observacoes livres do cliente.
            TextFormField(
              controller: _obsCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Observacoes',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.sticky_note_2),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selecionarDataNascimento,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data de Nascimento (opcional)',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: _dataNascimento == null
                      ? const Icon(Icons.calendar_month)
                      : IconButton(
                          onPressed: () => setState(() => _dataNascimento = null),
                          icon: const Icon(Icons.close),
                        ),
                ),
                child: Text(
                  _dataNascimento == null
                      ? 'Selecionar data'
                      : AppFormatters.date(_dataNascimento!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botao auxiliar de salvar no corpo da tela.
            ElevatedButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.save),
              label: Text(_edicao ? 'Atualizar Cliente' : 'Criar Cliente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
