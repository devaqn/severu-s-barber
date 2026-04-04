// ============================================================
// atendimento_controller.dart
// Controller para gerenciamento de atendimentos com ChangeNotifier.
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/atendimento.dart';
import '../services/atendimento_service.dart';

/// Controller central para carregar, registrar e remover atendimentos.
class AtendimentoController extends ChangeNotifier {
  // Servico de acesso a dados de atendimentos.
  final AtendimentoService _service = AtendimentoService();

  // Lista de atendimentos exibidos na UI.
  List<Atendimento> atendimentos = [];

  // Flag global de carregamento para controle visual.
  bool isLoading = false;

  /// Carrega atendimentos recentes e notifica listeners.
  Future<void> carregar() async {
    isLoading = true;
    notifyListeners();
    try {
      atendimentos = await _service.getAll(limit: 100);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Registra um atendimento, processa efeitos e recarrega a lista.
  Future<void> registrarAtendimento(Atendimento atendimento) async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.registrar(atendimento);
      await carregar();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Remove um atendimento e atualiza estado local.
  Future<void> deletar(int id) async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.delete(id);
      atendimentos.removeWhere((a) => a.id == id);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
