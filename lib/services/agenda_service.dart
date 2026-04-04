// ============================================================
// agenda_service.dart
// Serviço de agendamentos: CRUD e consultas por data.
// ============================================================

import '../database/database_helper.dart';
import '../models/agendamento.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';

class AgendaService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Agendamento>> getAll() async {
    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      orderBy: 'data_hora ASC',
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList();
  }

  Future<List<Agendamento>> getDodia(DateTime data) async {
    final inicio = DateTime(data.year, data.month, data.day).toIso8601String();
    final fim =
        DateTime(data.year, data.month, data.day, 23, 59, 59).toIso8601String();

    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: 'data_hora BETWEEN ? AND ?',
      whereArgs: [inicio, fim],
      orderBy: 'data_hora ASC',
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList();
  }

  Future<List<Agendamento>> getMes(int ano, int mes) async {
    SecurityUtils.sanitizeIntRange(
      ano,
      fieldName: 'Ano',
      min: 2000,
      max: 2100,
    );
    SecurityUtils.sanitizeIntRange(
      mes,
      fieldName: 'Mes',
      min: 1,
      max: 12,
    );

    final inicio = DateTime(ano, mes, 1).toIso8601String();
    final fim = DateTime(ano, mes + 1, 0, 23, 59, 59).toIso8601String();

    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: 'data_hora BETWEEN ? AND ?',
      whereArgs: [inicio, fim],
      orderBy: 'data_hora ASC',
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList();
  }

  Future<int> insert(Agendamento agendamento) async {
    final safeAgendamento = _sanitizarAgendamento(agendamento);
    return await _db.insert(
      AppConstants.tableAgendamentos,
      safeAgendamento.toMap(),
    );
  }

  Future<void> update(Agendamento agendamento) async {
    SecurityUtils.ensure(agendamento.id != null, 'ID do agendamento invalido.');
    final safeAgendamento = _sanitizarAgendamento(agendamento);
    await _db.update(
      AppConstants.tableAgendamentos,
      safeAgendamento.toMap(),
      'id = ?',
      [safeAgendamento.id],
    );
  }

  Future<void> updateStatus(int id, String status) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do agendamento',
      min: 1,
      max: 1 << 30,
    );
    final safeStatus = SecurityUtils.sanitizeEnumValue(
      status,
      fieldName: 'Status',
      allowedValues: AppConstants.statusAgendamento,
    );

    await _db.update(
      AppConstants.tableAgendamentos,
      {'status': safeStatus},
      'id = ?',
      [id],
    );
  }

  Future<void> delete(int id) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do agendamento',
      min: 1,
      max: 1 << 30,
    );
    await _db.delete(AppConstants.tableAgendamentos, 'id = ?', [id]);
  }

  /// Retorna agendamentos futuros pendentes
  Future<List<Agendamento>> getProximos({int limit = 5}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 100,
    );
    final agora = DateTime.now().toIso8601String();
    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: "data_hora >= ? AND status NOT IN ('Cancelado', 'Concluído')",
      whereArgs: [agora],
      orderBy: 'data_hora ASC',
      limit: safeLimit,
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList();
  }

  Agendamento _sanitizarAgendamento(Agendamento agendamento) {
    final safeClienteNome = SecurityUtils.sanitizeName(
      agendamento.clienteNome,
      fieldName: 'Nome do cliente',
    );
    final safeServicoNome = SecurityUtils.sanitizeName(
      agendamento.servicoNome,
      fieldName: 'Nome do servico',
    );
    final safeStatus = SecurityUtils.sanitizeEnumValue(
      agendamento.status,
      fieldName: 'Status',
      allowedValues: AppConstants.statusAgendamento,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      agendamento.observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    return agendamento.copyWith(
      clienteNome: safeClienteNome,
      servicoNome: safeServicoNome,
      status: safeStatus,
      observacoes: safeObs,
    );
  }
}
