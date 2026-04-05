// ============================================================
// cliente_controller.dart
// Controller para CRUD e busca de clientes com ChangeNotifier.
// ============================================================

import 'package:flutter/foundation.dart';
import 'dart:async';
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
  String _query = '';
  StreamSubscription<List<Cliente>>? _sub;

  /// Carrega clientes e reseta filtro atual.
  Future<void> carregar() async {
    isLoading = true;
    notifyListeners();
    try {
      _sub ??= _service.streamClientes().listen((dados) {
        clientes = List<Cliente>.from(dados);
        _aplicarFiltro();
      });
      final inicial = await _service.getAll();
      clientes = List<Cliente>.from(inicial);
      _aplicarFiltro();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Busca clientes por nome em tempo real.
  Future<void> buscar(String query) async {
    _query = query.trim();
    _aplicarFiltro();
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

  void _aplicarFiltro() {
    if (_query.isEmpty) {
      clientesFiltrados = List<Cliente>.from(clientes);
      notifyListeners();
      return;
    }

    final normalized = _query.toLowerCase();
    clientesFiltrados = clientes.where((cliente) {
      return cliente.nome.toLowerCase().contains(normalized) ||
          cliente.telefone.contains(normalized);
    }).toList(growable: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
