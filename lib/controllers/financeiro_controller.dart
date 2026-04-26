import 'package:flutter/foundation.dart';

import '../models/caixa.dart';
import '../models/despesa.dart';
import '../services/financeiro_service.dart';
import 'controller_mixin.dart';

class FinanceiroController extends ChangeNotifier with ControllerMixin {
  FinanceiroController({FinanceiroService? financeiroService})
      : _service = financeiroService ?? FinanceiroService();

  final FinanceiroService _service;

  List<Despesa> despesas = [];
  Map<String, double> resumo = const {
    'faturamento': 0,
    'despesas': 0,
    'lucro': 0,
  };

  Future<void> carregarResumo({
    required DateTime inicio,
    required DateTime fim,
  }) =>
      runSilent(() async {
        resumo = await _service.getResumo(inicio, fim);
        despesas = await _service.getDespesas(inicio: inicio, fim: fim);
      });

  Future<List<Despesa>> getDespesas({DateTime? inicio, DateTime? fim}) async {
    despesas =
        await runCatch(() => _service.getDespesas(inicio: inicio, fim: fim)) ??
            const [];
    return despesas;
  }

  Future<Map<String, double>> getResumo(DateTime inicio, DateTime fim) async {
    resumo = await runCatch(() => _service.getResumo(inicio, fim)) ??
        const {'faturamento': 0, 'despesas': 0, 'lucro': 0};
    return resumo;
  }

  Future<int> insertDespesa(Despesa despesa) =>
      runOrThrow(() => _service.insertDespesa(despesa));

  Future<void> updateDespesa(Despesa despesa) =>
      runOrThrow(() => _service.updateDespesa(despesa));

  Future<void> deleteDespesa(int id) =>
      runOrThrow(() => _service.deleteDespesa(id));

  Future<Caixa?> getCaixaAberto() =>
      runCatch(() => _service.getCaixaAberto());
}
