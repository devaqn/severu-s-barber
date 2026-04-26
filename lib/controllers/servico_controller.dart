import 'package:flutter/foundation.dart';

import '../models/servico.dart';
import '../services/servico_service.dart';
import 'controller_mixin.dart';

class ServicoController extends ChangeNotifier with ControllerMixin {
  ServicoController({ServicoService? servicoService})
      : _service = servicoService ?? ServicoService();

  final ServicoService _service;

  List<Servico> servicos = [];

  Future<void> carregar({bool apenasAtivos = true}) => runSilent(() async {
        servicos = await _service.getAll(apenasAtivos: apenasAtivos);
      });

  Future<List<Servico>> getAll({bool apenasAtivos = true}) async {
    final dados =
        await runCatch(() => _service.getAll(apenasAtivos: apenasAtivos));
    servicos = dados != null ? List<Servico>.from(dados) : const [];
    return servicos;
  }

  Future<Servico?> getById(int id) => runCatch(() => _service.getById(id));

  Future<int> insert(Servico servico) =>
      runOrThrow(() => _service.insert(servico));

  Future<void> update(Servico servico) =>
      runOrThrow(() => _service.update(servico));

  Future<void> delete(int id) => runOrThrow(() => _service.delete(id));
}
