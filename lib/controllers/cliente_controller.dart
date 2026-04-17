// ============================================================
// cliente_controller.dart
// Controller para CRUD e busca de clientes com ChangeNotifier.
// ============================================================

import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/atendimento.dart';
import '../models/cliente.dart';
import '../services/cliente_service.dart';

/// Controller de clientes com estado de lista completa e filtrada.
class ClienteController extends ChangeNotifier {
  ClienteController({ClienteService? clienteService})
      : _service = clienteService ?? ClienteService();

  final ClienteService _service;

  // Lista completa carregada do banco.
  List<Cliente> clientes = [];

  // Lista efetivamente exibida apos filtro de busca.
  List<Cliente> clientesFiltrados = [];

  // Indicador de carregamento para a tela.
  bool isLoading = false;
  String? errorMsg;
  String _query = '';
  StreamSubscription<List<Cliente>>? _sub;

  /// Carrega clientes e reseta filtro atual.
  Future<void> carregar() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      _sub ??= _service.streamClientes().listen((dados) {
        clientes = List<Cliente>.from(dados);
        _aplicarFiltro();
      });
      final inicial = await _service.getAll();
      clientes = List<Cliente>.from(inicial);
      _aplicarFiltro();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
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
    errorMsg = null;
    notifyListeners();
    try {
      if (cliente.id == null) {
        await _service.insert(cliente);
      } else {
        await _service.update(cliente);
      }
      await carregar();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Remove cliente por id e atualiza listas locais.
  Future<void> deletar(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.delete(id);
      clientes.removeWhere((c) => c.id == id);
      clientesFiltrados.removeWhere((c) => c.id == id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Cliente?> getById(int id) async {
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

  Future<List<Cliente>> search(String query) async {
    errorMsg = null;
    try {
      return await _service.search(query);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return const <Cliente>[];
    }
  }

  Future<List<Atendimento>> getHistorico(int clienteId) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getHistorico(clienteId);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Atendimento>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resgatarFidelidade(int clienteId) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.resgatarFidelidade(clienteId);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Cliente>> getRanking({int limit = 20}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getRanking(limit: limit);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Cliente>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Cliente>> aniversariantesHoje() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.aniversariantesHoje();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Cliente>[];
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
