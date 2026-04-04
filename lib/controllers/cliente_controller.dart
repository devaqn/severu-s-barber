// ============================================================
// cliente_controller.dart
// Controller para CRUD e busca de clientes com ChangeNotifier.
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../services/cliente_service.dart';

/// Controller de clientes com estado de lista completa e filtrada.
class ClienteController extends ChangeNotifier {
  // Servico de dados de clientes.
  final ClienteService _service = ClienteService();

  // Lista completa carregada do banco.
  List<Cliente> clientes = [];

  // Lista efetivamente exibida apos filtro de busca.
  List<Cliente> clientesFiltrados = [];

  // Indicador de carregamento para a tela.
  bool isLoading = false;

  /// Carrega clientes e reseta filtro atual.
  Future<void> carregar() async {
    isLoading = true;
    notifyListeners();
    try {
      clientes = await _service.getAll();
      clientesFiltrados = List<Cliente>.from(clientes);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Busca clientes por nome em tempo real.
  Future<void> buscar(String query) async {
    if (query.trim().isEmpty) {
      clientesFiltrados = List<Cliente>.from(clientes);
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      clientesFiltrados = await _service.search(query.trim());
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Salva cliente novo ou existente e recarrega a lista.
  Future<void> salvar(Cliente cliente) async {
    isLoading = true;
    notifyListeners();
    try {
      if (cliente.id == null) {
        await _service.insert(cliente);
      } else {
        await _service.update(cliente);
      }
      await carregar();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Remove cliente por id e atualiza listas locais.
  Future<void> deletar(int id) async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.delete(id);
      clientes.removeWhere((c) => c.id == id);
      clientesFiltrados.removeWhere((c) => c.id == id);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
