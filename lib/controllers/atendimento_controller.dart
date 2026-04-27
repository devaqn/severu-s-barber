import 'package:flutter/foundation.dart';

import '../models/atendimento.dart';
import '../services/atendimento_service.dart';
import 'controller_mixin.dart';

class AtendimentoController extends ChangeNotifier with ControllerMixin {
  AtendimentoController({AtendimentoService? atendimentoService})
      : _service = atendimentoService ?? AtendimentoService();

  final AtendimentoService _service;

  List<Atendimento> atendimentos = [];

  Future<void> carregar() => runSilent(() async {
        atendimentos = await _service.getAll(limit: 100);
      });

  Future<List<Atendimento>> getPorPeriodo(DateTime inicio, DateTime fim) async {
    final dados = await runCatch(() => _service.getPorPeriodo(inicio, fim));
    atendimentos = dados != null ? List<Atendimento>.from(dados) : const [];
    return atendimentos;
  }

  Future<int> registrar(Atendimento atendimento) =>
      runOrThrow(() => _service.registrar(atendimento));

  Future<void> registrarAtendimento(Atendimento atendimento) =>
      runOrThrow(() async {
        await _service.registrar(atendimento);
        await _service.getAll(limit: 100).then((v) => atendimentos = v);
      });

  Future<void> deletar(int id) => runOrThrow(() async {
        await _service.delete(id);
        atendimentos.removeWhere((a) => a.id == id);
      });
}
