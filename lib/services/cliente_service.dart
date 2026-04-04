import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_helper.dart';
import '../models/atendimento.dart';
import '../models/cliente.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'service_exceptions.dart';

class ClienteService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Cliente>> getAll() async {
    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<Cliente?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );
    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      where: 'id = ?',
      whereArgs: [safeId],
    );
    if (maps.isEmpty) return null;
    return Cliente.fromMap(maps.first);
  }

  Future<List<Cliente>> search(String query) async {
    final normalized = SecurityUtils.normalizeUtf8(
      query,
      maxLength: 80,
      allowNewLines: false,
    );
    if (normalized.length < 2) return <Cliente>[];

    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      where: 'nome LIKE ?',
      whereArgs: ['%$normalized%'],
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<int> insert(Cliente cliente) async {
    final safeCliente = _sanitizarCliente(cliente);
    return _db.insert(AppConstants.tableClientes, safeCliente.toMap());
  }

  Future<void> update(Cliente cliente) async {
    SecurityUtils.ensure(cliente.id != null, 'ID do cliente invalido.');
    final safeCliente = _sanitizarCliente(
      cliente.copyWith(updatedAt: DateTime.now()),
    );

    await _db.update(
      AppConstants.tableClientes,
      safeCliente.toMap(),
      'id = ?',
      [safeCliente.id],
    );
  }

  Future<void> delete(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );
    await _db.delete(AppConstants.tableClientes, 'id = ?', [safeId]);
  }

  Future<List<Atendimento>> getHistorico(int clienteId) async {
    final safeClienteId = SecurityUtils.sanitizeIntRange(
      clienteId,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'cliente_id = ?',
      whereArgs: [safeClienteId],
      orderBy: 'data DESC',
    );
    return maps.map((m) => Atendimento.fromMap(m)).toList();
  }

  Future<void> atualizarAposAtendimento(
    int clienteId,
    double valor, {
    DatabaseExecutor? executor,
  }) async {
    final safeClienteId = SecurityUtils.sanitizeIntRange(
      clienteId,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valor,
      fieldName: 'Valor do atendimento',
      min: 0,
      max: 999999,
    );

    if (executor != null) {
      await _atualizarAposAtendimento(executor, safeClienteId, safeValor);
      return;
    }

    await _db.transaction((txn) async {
      await _atualizarAposAtendimento(txn, safeClienteId, safeValor);
    });
  }

  Future<void> _atualizarAposAtendimento(
    DatabaseExecutor executor,
    int clienteId,
    double valor,
  ) async {
    final rows = await executor.query(
      AppConstants.tableClientes,
      columns: ['total_gasto', 'total_atendimentos', 'pontos_fidelidade'],
      where: 'id = ?',
      whereArgs: [clienteId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const NotFoundException('Cliente nao encontrado para atualizacao.');
    }

    final row = rows.first;
    final totalGastoAtual = (row['total_gasto'] as num?)?.toDouble() ?? 0.0;
    final totalAtendimentosAtual =
        (row['total_atendimentos'] as num?)?.toInt() ?? 0;
    final pontosAtual = (row['pontos_fidelidade'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().toIso8601String();
    await executor.update(
      AppConstants.tableClientes,
      {
        'total_gasto': totalGastoAtual + valor,
        'ultima_visita': now,
        'total_atendimentos': totalAtendimentosAtual + 1,
        'pontos_fidelidade': pontosAtual + 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [clienteId],
    );
  }

  Future<void> resgatarFidelidade(int clienteId) async {
    final safeClienteId = SecurityUtils.sanitizeIntRange(
      clienteId,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );

    final cliente = await getById(safeClienteId);
    if (cliente == null) {
      throw const NotFoundException('Cliente nao encontrado.');
    }

    final novoPontos = cliente.pontosFidelidade - 10;
    final atualizado = cliente.copyWith(
      pontosFidelidade: novoPontos < 0 ? 0 : novoPontos,
      updatedAt: DateTime.now(),
    );
    await update(atualizado);
  }

  Future<List<Map<String, dynamic>>> getClientesSumidos() async {
    final clientes = await getAll();
    final sumidos = <Map<String, dynamic>>[];

    for (final cliente in clientes) {
      if (cliente.totalAtendimentos < 2 || cliente.ultimaVisita == null) {
        continue;
      }

      final atendimentos = await getHistorico(cliente.id!);
      if (atendimentos.length < 2) continue;

      var somaIntervalos = 0;
      for (var i = 0; i < atendimentos.length - 1; i++) {
        final diff = atendimentos[i]
            .data
            .difference(atendimentos[i + 1].data)
            .inDays
            .abs();
        somaIntervalos += diff;
      }
      final mediaIntervaloDias = somaIntervalos / (atendimentos.length - 1);
      final diasSemVir =
          DateTime.now().difference(cliente.ultimaVisita!).inDays;
      final limite = mediaIntervaloDias + AppConstants.diasToleranciaCliente;

      if (diasSemVir > limite) {
        sumidos.add({
          'cliente': cliente,
          'diasSemVir': diasSemVir,
          'mediaIntervalo': mediaIntervaloDias.round(),
        });
      }
    }

    sumidos.sort(
      (a, b) => (b['diasSemVir'] as int).compareTo(a['diasSemVir'] as int),
    );
    return sumidos;
  }

  Future<List<Cliente>> getRanking({int limit = 10}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 100,
    );

    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      orderBy: 'total_gasto DESC',
      limit: safeLimit,
    );
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Cliente _sanitizarCliente(Cliente cliente) {
    final safeNome =
        SecurityUtils.sanitizeName(cliente.nome, fieldName: 'Nome do cliente');
    final safeTelefone = SecurityUtils.sanitizePhone(cliente.telefone);
    final safeObs = SecurityUtils.sanitizeOptionalText(
      cliente.observacoes,
      maxLength: 500,
      allowNewLines: true,
    );
    final safeTotalGasto = SecurityUtils.sanitizeDoubleRange(
      cliente.totalGasto,
      fieldName: 'Total gasto',
      min: 0,
      max: 999999999,
    );
    final safePontos = SecurityUtils.sanitizeIntRange(
      cliente.pontosFidelidade,
      fieldName: 'Pontos de fidelidade',
      min: 0,
      max: 100000,
    );
    final safeTotalAtendimentos = SecurityUtils.sanitizeIntRange(
      cliente.totalAtendimentos,
      fieldName: 'Total de atendimentos',
      min: 0,
      max: 1000000,
    );

    return cliente.copyWith(
      nome: safeNome,
      telefone: safeTelefone,
      observacoes: safeObs,
      totalGasto: safeTotalGasto,
      pontosFidelidade: safePontos,
      totalAtendimentos: safeTotalAtendimentos,
    );
  }
}
