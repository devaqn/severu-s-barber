import 'package:flutter/foundation.dart';

import '../models/caixa.dart';
import '../models/despesa.dart';
import '../services/financeiro_service.dart';

class FinanceiroController extends ChangeNotifier {
  FinanceiroController({FinanceiroService? financeiroService})
      : _service = financeiroService ?? FinanceiroService();

  final FinanceiroService _service;

  bool isLoading = false;
  String? errorMsg;
  List<Despesa> despesas = [];
  Map<String, double> resumo = const {
    'faturamento': 0,
    'despesas': 0,
    'lucro': 0,
  };

  Future<void> carregarResumo({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      resumo = await _service.getResumo(inicio, fim);
      despesas = await _service.getDespesas(inicio: inicio, fim: fim);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Despesa>> getDespesas({DateTime? inicio, DateTime? fim}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      despesas = await _service.getDespesas(inicio: inicio, fim: fim);
      return despesas;
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Despesa>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, double>> getResumo(DateTime inicio, DateTime fim) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      resumo = await _service.getResumo(inicio, fim);
      return resumo;
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const {'faturamento': 0, 'despesas': 0, 'lucro': 0};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<int> insertDespesa(Despesa despesa) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.insertDespesa(despesa);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDespesa(Despesa despesa) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.updateDespesa(despesa);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDespesa(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.deleteDespesa(id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Caixa?> getCaixaAberto() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getCaixaAberto();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
