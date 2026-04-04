// ============================================================
// servico_service.dart
// Serviço CRUD para os serviços oferecidos pela barbearia.
// ============================================================

import '../database/database_helper.dart';
import '../models/servico.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';

class ServicoService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Servico>> getAll({bool apenasAtivos = true}) async {
    final maps = await _db.queryAll(
      AppConstants.tableServicos,
      where: apenasAtivos ? 'ativo = 1' : null,
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Servico.fromMap(m)).toList();
  }

  Future<Servico?> getById(int id) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do servico',
      min: 1,
      max: 1 << 30,
    );
    final maps = await _db.queryAll(
      AppConstants.tableServicos,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Servico.fromMap(maps.first);
  }

  Future<int> insert(Servico servico) async {
    final safeServico = _sanitizarServico(servico);
    return await _db.insert(AppConstants.tableServicos, safeServico.toMap());
  }

  Future<void> update(Servico servico) async {
    SecurityUtils.ensure(servico.id != null, 'ID do servico invalido.');
    final safeServico = _sanitizarServico(servico);
    await _db.update(
      AppConstants.tableServicos,
      safeServico.toMap(),
      'id = ?',
      [safeServico.id],
    );
  }

  Future<void> delete(int id) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do servico',
      min: 1,
      max: 1 << 30,
    );
    // Desativa em vez de deletar para preservar histórico
    await _db.update(
      AppConstants.tableServicos,
      {'ativo': 0},
      'id = ?',
      [id],
    );
  }

  /// Retorna os serviços mais realizados com a contagem
  Future<List<Map<String, dynamic>>> getMaisRealizados({int limit = 5}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 100,
    );

    return await _db.rawQuery('''
      SELECT 
        ai.nome,
        SUM(ai.quantidade) as total_vendas,
        SUM(ai.quantidade * ai.preco_unitario) as faturamento_total
      FROM ${AppConstants.tableAtendimentoItens} ai
      WHERE ai.tipo = 'servico'
      GROUP BY ai.nome
      ORDER BY total_vendas DESC
      LIMIT ?
    ''', [safeLimit]);
  }

  Servico _sanitizarServico(Servico servico) {
    final safeNome =
        SecurityUtils.sanitizeName(servico.nome, fieldName: 'Nome do servico');
    final safePreco = SecurityUtils.sanitizeDoubleRange(
      servico.preco,
      fieldName: 'Preco',
      min: 0.01,
      max: 99999,
    );
    final safeDuracao = SecurityUtils.sanitizeIntRange(
      servico.duracaoMinutos,
      fieldName: 'Duracao',
      min: 5,
      max: 720,
    );
    final safeComissao = SecurityUtils.sanitizeDoubleRange(
      servico.comissaoPercentual,
      fieldName: 'Comissao',
      min: 0,
      max: 1,
    );

    return servico.copyWith(
      nome: safeNome,
      preco: safePreco,
      duracaoMinutos: safeDuracao,
      comissaoPercentual: safeComissao,
    );
  }
}
