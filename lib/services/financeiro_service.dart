// ============================================================
// financeiro_service.dart
// Serviço financeiro: controle de despesas, cálculo de lucro,
// simulador de preços e relatórios financeiros.
// ============================================================

import '../database/database_helper.dart';
import '../models/despesa.dart';
import '../models/caixa.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'atendimento_service.dart';
import 'service_exceptions.dart';
import 'dart:convert';

class FinanceiroService {
  final DatabaseHelper _db = DatabaseHelper();
  final AtendimentoService _atendimentoService = AtendimentoService();
  static final Set<String> _categoriasAceitas = {
    ...AppConstants.categoriasDespesa,
    'Luz',
  };

  // ── Despesas ─────────────────────────────────────────────────

  Future<List<Despesa>> getDespesas({DateTime? inicio, DateTime? fim}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (inicio != null && fim != null) {
      SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
      where = 'data BETWEEN ? AND ?';
      whereArgs = [inicio.toIso8601String(), fim.toIso8601String()];
    }

    final maps = await _db.queryAll(
      AppConstants.tableDespesas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data DESC',
    );
    return maps.map((m) => Despesa.fromMap(m)).toList();
  }

  Future<int> insertDespesa(Despesa despesa) async {
    final safeDespesa = _sanitizarDespesa(despesa);
    return await _db.insert(AppConstants.tableDespesas, safeDespesa.toMap());
  }

  Future<void> updateDespesa(Despesa despesa) async {
    SecurityUtils.ensure(despesa.id != null, 'ID da despesa invalido.');
    final safeDespesa = _sanitizarDespesa(despesa);
    await _db.update(
      AppConstants.tableDespesas,
      safeDespesa.toMap(),
      'id = ?',
      [safeDespesa.id],
    );
  }

  Future<void> deleteDespesa(int id) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID da despesa',
      min: 1,
      max: 1 << 30,
    );
    await _db.delete(AppConstants.tableDespesas, 'id = ?', [id]);
  }

  /// Total de despesas no período
  Future<double> getTotalDespesas(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final result = await _db.rawQuery('''
      SELECT SUM(valor) as total
      FROM ${AppConstants.tableDespesas}
      WHERE data BETWEEN ? AND ?
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Despesas agrupadas por categoria
  Future<List<Map<String, dynamic>>> getDespesasPorCategoria(
      DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    return await _db.rawQuery('''
      SELECT categoria, SUM(valor) as total
      FROM ${AppConstants.tableDespesas}
      WHERE data BETWEEN ? AND ?
      GROUP BY categoria
      ORDER BY total DESC
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
  }

  // ── Resumo financeiro ────────────────────────────────────────

  /// Retorna resumo financeiro completo de um período
  Future<Map<String, double>> getResumo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final faturamento =
        await _atendimentoService.getFaturamentoPeriodo(inicio, fim);
    final despesas = await getTotalDespesas(inicio, fim);
    final lucro = faturamento - despesas;

    return {
      'faturamento': faturamento,
      'despesas': despesas,
      'lucro': lucro,
    };
  }

  // ── Caixa ────────────────────────────────────────────────────

  /// Verifica se há um caixa aberto
  Future<Caixa?> getCaixaAberto() async {
    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      where: "status = 'aberto'",
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Caixa.fromMap(maps.first);
  }

  Future<Caixa?> getUltimoCaixa() async {
    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Caixa.fromMap(maps.first);
  }

  Future<List<Caixa>> getCaixas({int limit = 30}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 365,
    );
    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      orderBy: 'data_abertura DESC',
      limit: safeLimit,
    );
    return maps.map((m) => Caixa.fromMap(m)).toList();
  }

  /// Abre um novo caixa
  Future<int> abrirCaixa({double valorInicial = 0.0}) async {
    final safeValorInicial = SecurityUtils.sanitizeDoubleRange(
      valorInicial,
      fieldName: 'Valor inicial',
      min: 0,
      max: 999999,
    );

    final caixaAberto = await getCaixaAberto();
    if (caixaAberto != null) {
      throw const ConflictException(
        'Ja existe um caixa aberto. Feche o caixa atual antes de abrir outro.',
      );
    }

    return await _db.insert(
      AppConstants.tableCaixas,
      Caixa(
        dataAbertura: DateTime.now(),
        valorInicial: safeValorInicial,
        status: AppConstants.caixaAberto,
      ).toMap(),
    );
  }

  /// Fecha o caixa atual com resumo por forma de pagamento
  Future<void> fecharCaixa(int caixaId) async {
    SecurityUtils.sanitizeIntRange(
      caixaId,
      fieldName: 'ID do caixa',
      min: 1,
      max: 1 << 30,
    );
    final agora = DateTime.now();
    final caixa = await getCaixaAberto();
    if (caixa == null) {
      throw const NotFoundException('Nao existe caixa aberto para fechamento.');
    }
    if (caixa.id != caixaId) {
      throw const ConflictException(
        'Caixa informado nao corresponde ao caixa aberto atual.',
      );
    }

    // Calcula o faturamento desde a abertura
    final pagamentos = await _atendimentoService.getFaturamentoPorPagamento(
      caixa.dataAbertura,
      agora,
    );

    final valorFinal =
        caixa.valorInicial + pagamentos.values.fold(0.0, (a, b) => a + b);

    await _db.update(
      AppConstants.tableCaixas,
      {
        'data_fechamento': agora.toIso8601String(),
        'valor_final': valorFinal,
        'status': AppConstants.caixaFechado,
        'resumo_pagamentos': jsonEncode(pagamentos),
      },
      'id = ?',
      [caixaId],
    );
  }

  // ── Simulador de lucro ───────────────────────────────────────

  /// Simula o impacto de alterar o preço de um serviço/produto
  /// Parâmetros:
  ///   - precoAtual: preço atual do item
  ///   - novoPreco: preço proposto
  ///   - mediaAtendimentosMes: quantos atendimentos por mês
  Map<String, double> simularMudancaPreco({
    required double precoAtual,
    required double novoPreco,
    required int mediaAtendimentosMes,
  }) {
    final safePrecoAtual = SecurityUtils.sanitizeDoubleRange(
      precoAtual,
      fieldName: 'Preco atual',
      min: 0,
      max: 999999,
    );
    final safeNovoPreco = SecurityUtils.sanitizeDoubleRange(
      novoPreco,
      fieldName: 'Novo preco',
      min: 0,
      max: 999999,
    );
    final safeMediaAtendimentos = SecurityUtils.sanitizeIntRange(
      mediaAtendimentosMes,
      fieldName: 'Media de atendimentos',
      min: 0,
      max: 1000000,
    );

    final faturamentoAtual = safePrecoAtual * safeMediaAtendimentos;
    final faturamentoNovo = safeNovoPreco * safeMediaAtendimentos;
    final diferenca = faturamentoNovo - faturamentoAtual;
    final percentual =
        faturamentoAtual > 0 ? (diferenca / faturamentoAtual) : 0.0;

    return {
      'faturamentoAtual': faturamentoAtual,
      'faturamentoNovo': faturamentoNovo,
      'diferenca': diferenca,
      'percentual': percentual,
    };
  }

  Despesa _sanitizarDespesa(Despesa despesa) {
    final safeDescricao = SecurityUtils.sanitizePlainText(
      despesa.descricao,
      fieldName: 'Descricao',
      minLength: 2,
      maxLength: 150,
      allowNewLines: false,
    );
    final safeCategoria = SecurityUtils.sanitizePlainText(
      despesa.categoria,
      fieldName: 'Categoria',
      minLength: 2,
      maxLength: 50,
      allowNewLines: false,
    );
    SecurityUtils.ensure(
      _categoriasAceitas.contains(safeCategoria),
      'Categoria de despesa invalida.',
    );
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      despesa.valor,
      fieldName: 'Valor',
      min: 0.01,
      max: 999999999,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      despesa.observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    return despesa.copyWith(
      descricao: safeDescricao,
      categoria: safeCategoria,
      valor: safeValor,
      observacoes: safeObs,
    );
  }
}
