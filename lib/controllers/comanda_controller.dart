import 'package:flutter/foundation.dart';

import '../models/comanda.dart';
import '../models/item_comanda.dart';
import '../services/comanda_service.dart';
import 'controller_mixin.dart';

class ComandaController extends ChangeNotifier with ControllerMixin {
  ComandaController({ComandaService? comandaService})
      : _service = comandaService ?? ComandaService();

  final ComandaService _service;

  List<Comanda> abertas = [];
  List<Comanda> fechadas = [];

  Future<void> carregar({String? barbeiroId}) => runSilent(() async {
        final results = await Future.wait<List<Comanda>>([
          _service.getAll(barbeiroId: barbeiroId, status: 'aberta'),
          _service.getAll(barbeiroId: barbeiroId, status: 'fechada'),
        ]);
        abertas = List<Comanda>.from(results[0]);
        fechadas = List<Comanda>.from(results[1]);
      });

  Future<List<Comanda>> getAll({String? barbeiroId, String? status}) async =>
      await runCatch(
            () => _service.getAll(barbeiroId: barbeiroId, status: status),
          ) ??
          const [];

  Future<Comanda?> getById(int id) => runCatch(() => _service.getById(id));

  Future<Comanda?> getComandaAberta({String? barbeiroId}) =>
      runCatch(() => _service.getComandaAberta(barbeiroId: barbeiroId));

  Future<List<Comanda>> getComandasHoje({String? barbeiroId}) async =>
      await runCatch(
            () => _service.getComandasHoje(barbeiroId: barbeiroId),
          ) ??
          const [];

  Future<Comanda> abrirComanda({
    int? clienteId,
    required String clienteNome,
    String? barbeiroId,
    String? barbeiroNome,
    String? observacoes,
  }) =>
      runOrThrow(() => _service.abrirComanda(
            clienteId: clienteId,
            clienteNome: clienteNome,
            barbeiroId: barbeiroId,
            barbeiroNome: barbeiroNome,
            observacoes: observacoes,
          ));

  Future<void> adicionarItem(int comandaId, ItemComanda item) =>
      runOrThrow(() => _service.adicionarItem(comandaId, item));

  Future<void> fecharComanda({
    required int comandaId,
    required String formaPagamento,
  }) =>
      runOrThrow(() => _service.fecharComanda(
            comandaId: comandaId,
            formaPagamento: formaPagamento,
          ));

  Future<double> getFaturamentoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async =>
      await runCatch(
            () => _service.getFaturamentoBarbeiro(barbeiroId, inicio, fim),
          ) ??
          0.0;

  Future<double> getComissaoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async =>
      await runCatch(
            () => _service.getComissaoBarbeiro(barbeiroId, inicio, fim),
          ) ??
          0.0;
}
