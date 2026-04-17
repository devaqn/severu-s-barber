// ============================================================
// atendimento_controller.dart
// Controller para gerenciamento de atendimentos com ChangeNotifier.
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/atendimento.dart';
import '../services/atendimento_service.dart';

/// Controller central para carregar, registrar e remover atendimentos.
class AtendimentoController extends ChangeNotifier {
  AtendimentoController({AtendimentoService? atendimentoService})
      : _service = atendimentoService ?? AtendimentoService();

  final AtendimentoService _service;

  // Lista de atendimentos exibidos na UI.
  List<Atendimento> atendimentos = [];

  // Flag global de carregamento para controle visual.
  bool isLoading = false;
  String? errorMsg;

  /// Carrega atendimentos recentes e notifica listeners.
  Future<void> carregar() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      atendimentos = await _service.getAll(limit: 100);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Atendimento>> getPorPeriodo(DateTime inicio, DateTime fim) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final dados = await _service.getPorPeriodo(inicio, fim);
      atendimentos = List<Atendimento>.from(dados);
      return dados;
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Atendimento>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<int> registrar(Atendimento atendimento) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.registrar(atendimento);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Registra um atendimento, processa efeitos e recarrega a lista.
  Future<void> registrarAtendimento(Atendimento atendimento) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.registrar(atendimento);
      await carregar();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Remove um atendimento e atualiza estado local.
  Future<void> deletar(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.delete(id);
      atendimentos.removeWhere((a) => a.id == id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
