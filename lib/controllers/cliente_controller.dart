import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/atendimento.dart';
import '../models/cliente.dart';
import '../services/cliente_service.dart';
import 'controller_mixin.dart';

class ClienteController extends ChangeNotifier with ControllerMixin {
  ClienteController({ClienteService? clienteService})
      : _service = clienteService ?? ClienteService();

  final ClienteService _service;

  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  String _query = '';
  StreamSubscription<List<Cliente>>? _sub;

  Future<void> carregar() => runSilent(() async {
        _sub ??= _service.streamClientes().listen((dados) {
          clientes = List<Cliente>.from(dados);
          _aplicarFiltro();
        });
        final inicial = await _service.getAll();
        clientes = List<Cliente>.from(inicial);
        _aplicarFiltro();
      });

  Future<void> buscar(String query) async {
    _query = query.trim();
    _aplicarFiltro();
  }

  Future<void> salvar(Cliente cliente) => runOrThrow(() async {
        if (cliente.id == null) {
          await _service.insert(cliente);
        } else {
          await _service.update(cliente);
        }
        await carregar();
      });

  Future<void> deletar(int id) => runOrThrow(() async {
        await _service.delete(id);
        clientes.removeWhere((c) => c.id == id);
        clientesFiltrados.removeWhere((c) => c.id == id);
      });

  Future<Cliente?> getById(int id) => runCatch(() => _service.getById(id));

  Future<List<Cliente>> search(String query) async =>
      await runCatch(() => _service.search(query)) ?? const <Cliente>[];

  Future<List<Atendimento>> getHistorico(int clienteId) async =>
      await runCatch(() => _service.getHistorico(clienteId)) ?? const [];

  Future<void> resgatarFidelidade(int clienteId) =>
      runOrThrow(() => _service.resgatarFidelidade(clienteId));

  Future<List<Cliente>> getRanking({int limit = 20}) async =>
      await runCatch(() => _service.getRanking(limit: limit)) ?? const [];

  Future<List<Cliente>> aniversariantesHoje() async =>
      await runCatch(() => _service.aniversariantesHoje()) ?? const [];

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
