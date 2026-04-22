import 'package:flutter/foundation.dart';

import '../models/comanda.dart';
import '../models/item_comanda.dart';
import '../services/comanda_service.dart';

class ComandaController extends ChangeNotifier {
  ComandaController({ComandaService? comandaService})
      : _service = comandaService ?? ComandaService();

  final ComandaService _service;

  bool isLoading = false;
  String? errorMsg;
  List<Comanda> abertas = [];
  List<Comanda> fechadas = [];

  Future<void> carregar({String? barbeiroId}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final results = await Future.wait<List<Comanda>>([
        _service.getAll(barbeiroId: barbeiroId, status: 'aberta'),
        _service.getAll(barbeiroId: barbeiroId, status: 'fechada'),
      ]);
      abertas = List<Comanda>.from(results[0]);
      fechadas = List<Comanda>.from(results[1]);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Comanda>> getAll({String? barbeiroId, String? status}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getAll(barbeiroId: barbeiroId, status: status);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Comanda>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Comanda?> getById(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getById(id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Comanda?> getComandaAberta({String? barbeiroId}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getComandaAberta(barbeiroId: barbeiroId);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Comanda>> getComandasHoje({String? barbeiroId}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getComandasHoje(barbeiroId: barbeiroId);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Comanda>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Comanda> abrirComanda({
    int? clienteId,
    required String clienteNome,
    String? barbeiroId,
    String? barbeiroNome,
    String? observacoes,
  }) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.abrirComanda(
        clienteId: clienteId,
        clienteNome: clienteNome,
        barbeiroId: barbeiroId,
        barbeiroNome: barbeiroNome,
        observacoes: observacoes,
      );
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> adicionarItem(int comandaId, ItemComanda item) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.adicionarItem(comandaId, item);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fecharComanda({
    required int comandaId,
    required String formaPagamento,
  }) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.fecharComanda(
        comandaId: comandaId,
        formaPagamento: formaPagamento,
      );
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<double> getFaturamentoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getFaturamentoBarbeiro(barbeiroId, inicio, fim);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return 0;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<double> getComissaoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getComissaoBarbeiro(barbeiroId, inicio, fim);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return 0;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
