import 'package:flutter/foundation.dart';

import '../models/agendamento.dart';
import '../services/agenda_service.dart';
import '../utils/constants.dart';
import 'controller_mixin.dart';

class AgendaController extends ChangeNotifier with ControllerMixin {
  AgendaController({AgendaService? agendaService})
      : _service = agendaService ?? AgendaService();

  final AgendaService _service;

  List<Agendamento> agendamentos = [];

  Future<void> carregar() => runSilent(() async {
        agendamentos = await _service.getAll();
      });

  Future<List<Agendamento>> getAll() async {
    final dados = await runCatch(() => _service.getAll());
    agendamentos = dados != null ? List<Agendamento>.from(dados) : const [];
    return agendamentos;
  }

  Future<int> insert(Agendamento agendamento) =>
      runOrThrow(() => _service.insert(agendamento));

  Future<void> update(Agendamento agendamento) =>
      runOrThrow(() => _service.update(agendamento));

  Future<void> updateStatus(
    int id,
    String status, {
    String? formaPagamento,
  }) =>
      runOrThrow(
        () => _service.updateStatus(
          id,
          status,
          formaPagamento: formaPagamento ?? AppConstants.pgDinheiro,
        ),
      );

  Future<void> delete(int id) => runOrThrow(() => _service.delete(id));
}
