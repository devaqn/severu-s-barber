import 'package:flutter/foundation.dart';

import '../models/servico.dart';
import '../services/servico_service.dart';

class ServicoController extends ChangeNotifier {
  ServicoController({ServicoService? servicoService})
      : _service = servicoService ?? ServicoService();

  final ServicoService _service;

  bool isLoading = false;
  String? errorMsg;
  List<Servico> servicos = [];

  Future<void> carregar({bool apenasAtivos = true}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      servicos = await _service.getAll(apenasAtivos: apenasAtivos);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Servico>> getAll({bool apenasAtivos = true}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final dados = await _service.getAll(apenasAtivos: apenasAtivos);
      servicos = List<Servico>.from(dados);
      return dados;
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Servico>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Servico?> getById(int id) async {
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

  Future<int> insert(Servico servico) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.insert(servico);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> update(Servico servico) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.update(servico);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> delete(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.delete(id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
