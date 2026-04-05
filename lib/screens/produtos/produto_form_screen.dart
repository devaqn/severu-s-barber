// ============================================================
// produto_form_screen.dart
// Formulario de cadastro e edicao de produtos.
// ============================================================

import 'package:flutter/material.dart';
import '../../models/fornecedor.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/security_utils.dart';

class ProdutoFormScreen extends StatefulWidget {
  final Produto? produto;
  const ProdutoFormScreen({super.key, this.produto});

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  // Chave para validacao do formulario.
  final _formKey = GlobalKey<FormState>();

  // Service de persistencia de produtos/fornecedores.
  final ProdutoService _service = ProdutoService();

  // Controllers dos campos principais do formulario.
  final _nomeCtrl = TextEditingController();
  final _vendaCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _comissaoCtrl = TextEditingController();

  // Lista de fornecedores carregada do banco.
  List<Fornecedor> _fornecedores = [];

  // Fornecedor selecionado no dropdown.
  int? _fornecedorId;

  // Estado de carregamento de dados auxiliares.
  bool _loading = true;

  // Estado de salvamento para bloquear a UI durante persistencia.
  bool _saving = false;

  bool get _isEditing => widget.produto != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.produto!;
      _nomeCtrl.text = p.nome;
      _vendaCtrl.text = p.precoVenda.toStringAsFixed(2);
      _custoCtrl.text = p.precoCusto.toStringAsFixed(2);
      _qtdCtrl.text = p.quantidade.toString();
      _minCtrl.text = p.estoqueMinimo.toString();
      _comissaoCtrl.text = (p.comissaoPercentual * 100).toStringAsFixed(0);
      _fornecedorId = p.fornecedorId;
    } else {
      _qtdCtrl.text = '0';
      _minCtrl.text = '3';
      _comissaoCtrl.text = '20';
    }
    _loadFornecedores();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _vendaCtrl.dispose();
    _custoCtrl.dispose();
    _qtdCtrl.dispose();
    _minCtrl.dispose();
    _comissaoCtrl.dispose();
    super.dispose();
  }

  // Exibe erro em snackbar vermelho.
  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  // Exibe sucesso em snackbar verde.
  void _sucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.successColor, content: Text(msg)),
    );
  }

  // Carrega fornecedores para o dropdown do formulario.
  Future<void> _loadFornecedores() async {
    setState(() => _loading = true);
    try {
      final f = await _service.getFornecedores();
      if (mounted) setState(() => _fornecedores = f);
    } catch (e) {
      _erro('Falha ao carregar fornecedores: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Salva ou atualiza o produto apos validacoes obrigatorias.
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final nome = SecurityUtils.sanitizeName(
        _nomeCtrl.text,
        fieldName: 'Nome do produto',
      );
      final precoVenda = SecurityUtils.sanitizeDoubleRange(
        double.parse(_vendaCtrl.text.replaceAll(',', '.')),
        fieldName: 'Preco de venda',
        min: 0.01,
        max: 999999,
      );
      final precoCusto = SecurityUtils.sanitizeDoubleRange(
        double.parse(_custoCtrl.text.replaceAll(',', '.')),
        fieldName: 'Preco de custo',
        min: 0,
        max: 999999,
      );
      final qtd = SecurityUtils.sanitizeIntRange(
        int.parse(_qtdCtrl.text),
        fieldName: 'Quantidade',
        min: 0,
        max: 1000000,
      );
      final min = SecurityUtils.sanitizeIntRange(
        int.parse(_minCtrl.text),
        fieldName: 'Estoque minimo',
        min: 0,
        max: 1000000,
      );
      final comissaoPercent = SecurityUtils.sanitizeDoubleRange(
        double.parse(_comissaoCtrl.text.replaceAll(',', '.')),
        fieldName: 'Comissao',
        min: 0,
        max: 100,
      );
      final comissaoDecimal = comissaoPercent / 100;

      if (_isEditing) {
        await _service.update(
          widget.produto!.copyWith(
            nome: nome,
            precoVenda: precoVenda,
            precoCusto: precoCusto,
            quantidade: qtd,
            estoqueMinimo: min,
            comissaoPercentual: comissaoDecimal,
            fornecedorId: _fornecedorId,
            updatedAt: now,
          ),
        );
      } else {
        await _service.insert(
          Produto(
            nome: nome,
            precoVenda: precoVenda,
            precoCusto: precoCusto,
            quantidade: qtd,
            estoqueMinimo: min,
            comissaoPercentual: comissaoDecimal,
            fornecedorId: _fornecedorId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (!mounted) return;
      _sucesso('Produto salvo com sucesso');
      Navigator.pop(context, true);
    } catch (e) {
      _erro('Falha ao salvar produto: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar:
          AppBar(title: Text(_isEditing ? 'Editar Produto' : 'Novo Produto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                prefixIcon: Icon(Icons.shopping_bag),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o nome';
                try {
                  SecurityUtils.sanitizeName(v);
                } catch (_) {
                  return 'Nome invalido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vendaCtrl,
              decoration: const InputDecoration(
                labelText: 'Preco de venda *',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Informe preco de venda valido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _custoCtrl,
              decoration: const InputDecoration(
                labelText: 'Preco de custo *',
                prefixIcon: Icon(Icons.money_off),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n < 0) return 'Informe preco de custo valido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtdCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantidade em estoque *',
                prefixIcon: Icon(Icons.inventory),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Informe quantidade valida';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minCtrl,
              decoration: const InputDecoration(
                labelText: 'Estoque minimo *',
                prefixIcon: Icon(Icons.warning),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Informe estoque minimo valido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _comissaoCtrl,
              decoration: const InputDecoration(
                labelText: 'Comissao (%) *',
                prefixIcon: Icon(Icons.percent),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n < 0 || n > 100) {
                  return 'Informe comissao entre 0 e 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _fornecedorId,
              decoration: const InputDecoration(
                labelText: 'Fornecedor',
                prefixIcon: Icon(Icons.business),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Sem fornecedor'),
                ),
                ..._fornecedores.map(
                  (f) => DropdownMenuItem<int>(
                    value: f.id,
                    child: Text(f.nome),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _fornecedorId = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _salvar,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvar Produto'),
            ),
          ],
        ),
      ),
    );
  }
}
