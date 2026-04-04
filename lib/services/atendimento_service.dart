import '../database/database_helper.dart';
import '../models/atendimento.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'cliente_service.dart';
import 'produto_service.dart';
import 'service_exceptions.dart';

class AtendimentoService {
  final DatabaseHelper _db = DatabaseHelper();
  final ClienteService _clienteService = ClienteService();
  final ProdutoService _produtoService = ProdutoService();

  Future<List<Atendimento>> getAll({int? limit}) async {
    if (limit != null) {
      SecurityUtils.sanitizeIntRange(
        limit,
        fieldName: 'Limite',
        min: 1,
        max: 1000,
      );
    }

    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      orderBy: 'data DESC',
      limit: limit,
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  Future<Atendimento?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do atendimento',
      min: 1,
      max: 1 << 30,
    );
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'id = ?',
      whereArgs: [safeId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final atendimento = Atendimento.fromMap(maps.first);
    final itens = await _getItensByAtendimentos([safeId]);
    return atendimento.copyWith(itens: itens[safeId] ?? const []);
  }

  Future<List<Atendimento>> getDodia() async {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
    final fim =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59).toIso8601String();

    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'data BETWEEN ? AND ?',
      whereArgs: [inicio, fim],
      orderBy: 'data DESC',
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  Future<List<Atendimento>> getPorPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'data BETWEEN ? AND ?',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'data DESC',
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  Future<List<Atendimento>> _anexarItens(List<Atendimento> atendimentos) async {
    if (atendimentos.isEmpty) return atendimentos;

    final ids =
        atendimentos.map((a) => a.id).whereType<int>().toList(growable: false);
    final itensPorAtendimento = await _getItensByAtendimentos(ids);

    return atendimentos
        .map(
          (a) => a.copyWith(
            itens: itensPorAtendimento[a.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<Map<int, List<AtendimentoItem>>> _getItensByAtendimentos(
    List<int> atendimentoIds,
  ) async {
    if (atendimentoIds.isEmpty) return <int, List<AtendimentoItem>>{};

    final placeholders = List.filled(atendimentoIds.length, '?').join(', ');
    final rows = await _db.rawQuery('''
      SELECT *
      FROM ${AppConstants.tableAtendimentoItens}
      WHERE atendimento_id IN ($placeholders)
      ORDER BY id ASC
    ''', atendimentoIds);

    final result = <int, List<AtendimentoItem>>{};
    for (final row in rows) {
      final item = AtendimentoItem.fromMap(row);
      final atendimentoId = item.atendimentoId;
      if (atendimentoId == null) continue;
      (result[atendimentoId] ??= <AtendimentoItem>[]).add(item);
    }
    return result;
  }

  Future<int> registrar(Atendimento atendimento) async {
    final safeAtendimento = _sanitizarAtendimento(atendimento);
    _validarTotal(safeAtendimento);

    final db = await _db.database;
    return db.transaction((txn) async {
      final atendimentoId = await txn.insert(
        AppConstants.tableAtendimentos,
        safeAtendimento.toMap(),
      );

      for (final item in safeAtendimento.itens) {
        await txn.insert(
          AppConstants.tableAtendimentoItens,
          _itemComAtendimento(item, atendimentoId).toMap(),
        );
      }

      for (final item in safeAtendimento.itens) {
        if (item.tipo != 'produto') continue;
        await _produtoService.baixarEstoqueComExecutor(
          executor: txn,
          produtoId: item.itemId,
          quantidade: item.quantidade,
          valorUnitario: item.precoUnitario,
          observacao: 'Atendimento #$atendimentoId',
        );
      }

      if (safeAtendimento.clienteId != null) {
        await _clienteService.atualizarAposAtendimento(
          safeAtendimento.clienteId!,
          safeAtendimento.total,
          executor: txn,
        );
      }

      return atendimentoId;
    });
  }

  Future<void> processar(
      Atendimento atendimentoIgnorado, int atendimentoId) async {
    SecurityUtils.sanitizeIntRange(
      atendimentoId,
      fieldName: 'ID do atendimento',
      min: 1,
      max: 1 << 30,
    );
    final existente = await getById(atendimentoId);
    if (existente == null) {
      throw const NotFoundException('Atendimento nao encontrado.');
    }
  }

  Future<void> delete(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do atendimento',
      min: 1,
      max: 1 << 30,
    );
    await _db.delete(AppConstants.tableAtendimentos, 'id = ?', [safeId]);
  }

  Future<double> getFaturamentoPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final result = await _db.rawQuery('''
      SELECT SUM(total) as total
      FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getFaturamentoPorDia(int dias) async {
    final safeDias = SecurityUtils.sanitizeIntRange(
      dias,
      fieldName: 'Quantidade de dias',
      min: 1,
      max: 3650,
    );
    final inicio =
        DateTime.now().subtract(Duration(days: safeDias)).toIso8601String();

    return _db.rawQuery('''
      SELECT 
        DATE(data) as dia,
        SUM(total) as total,
        COUNT(*) as quantidade
      FROM ${AppConstants.tableAtendimentos}
      WHERE data >= ?
      GROUP BY DATE(data)
      ORDER BY dia ASC
    ''', [inicio]);
  }

  Future<Map<String, double>> getFaturamentoPorPagamento(
    DateTime inicio,
    DateTime fim,
  ) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final result = await _db.rawQuery('''
      SELECT forma_pagamento, SUM(total) as total
      FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
      GROUP BY forma_pagamento
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);

    return {
      for (final row in result)
        row['forma_pagamento'] as String: (row['total'] as num).toDouble(),
    };
  }

  Future<int> getCountPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as total
      FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getHorariosMaisLucrativos() async {
    return _db.rawQuery('''
      SELECT 
        CAST(strftime('%H', data) AS INTEGER) as hora,
        COUNT(*) as quantidade,
        SUM(total) as faturamento
      FROM ${AppConstants.tableAtendimentos}
      GROUP BY hora
      ORDER BY faturamento DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getMapaHorarios() async {
    return _db.rawQuery('''
      SELECT 
        CAST(strftime('%H', data) AS INTEGER) as hora,
        COUNT(*) as total_atendimentos,
        SUM(total) as total_faturamento
      FROM ${AppConstants.tableAtendimentos}
      GROUP BY hora
      ORDER BY hora ASC
    ''');
  }

  void _validarTotal(Atendimento atendimento) {
    if (atendimento.itens.isEmpty) {
      throw const ValidationException(
        'Atendimento deve conter ao menos um item.',
      );
    }

    final totalCalculado =
        atendimento.itens.fold<double>(0, (soma, item) => soma + item.subtotal);
    if ((totalCalculado - atendimento.total).abs() > 0.01) {
      throw const ValidationException(
        'Total do atendimento nao confere com os itens selecionados.',
      );
    }
  }

  Atendimento _sanitizarAtendimento(Atendimento atendimento) {
    final safeClienteNome = SecurityUtils.sanitizeName(
      atendimento.clienteNome,
      fieldName: 'Nome do cliente',
    );
    final safeFormaPagamento = SecurityUtils.sanitizeEnumValue(
      atendimento.formaPagamento,
      fieldName: 'Forma de pagamento',
      allowedValues: AppConstants.formasPagamento,
    );
    final safeTotal = SecurityUtils.sanitizeDoubleRange(
      atendimento.total,
      fieldName: 'Total',
      min: 0.01,
      max: 999999,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      atendimento.observacoes,
      maxLength: 600,
      allowNewLines: true,
    );
    final safeItens = atendimento.itens.map(_sanitizarItem).toList();

    return atendimento.copyWith(
      clienteNome: safeClienteNome,
      formaPagamento: safeFormaPagamento,
      total: safeTotal,
      observacoes: safeObs,
      itens: safeItens,
    );
  }

  AtendimentoItem _sanitizarItem(AtendimentoItem item) {
    final safeTipo = SecurityUtils.sanitizeEnumValue(
      item.tipo,
      fieldName: 'Tipo do item',
      allowedValues: const ['servico', 'produto'],
    );
    final safeItemId = SecurityUtils.sanitizeIntRange(
      item.itemId,
      fieldName: 'ID do item',
      min: 1,
      max: 1 << 30,
    );
    final safeNome = SecurityUtils.sanitizeName(
      item.nome,
      fieldName: 'Nome do item',
      maxLength: 120,
    );
    final safeQuantidade = SecurityUtils.sanitizeIntRange(
      item.quantidade,
      fieldName: 'Quantidade do item',
      min: 1,
      max: 1000,
    );
    final safePreco = SecurityUtils.sanitizeDoubleRange(
      item.precoUnitario,
      fieldName: 'Preco unitario',
      min: 0.01,
      max: 999999,
    );

    return AtendimentoItem(
      id: item.id,
      atendimentoId: item.atendimentoId,
      tipo: safeTipo,
      itemId: safeItemId,
      nome: safeNome,
      quantidade: safeQuantidade,
      precoUnitario: safePreco,
    );
  }

  AtendimentoItem _itemComAtendimento(AtendimentoItem item, int atendimentoId) {
    return AtendimentoItem(
      id: item.id,
      atendimentoId: atendimentoId,
      tipo: item.tipo,
      itemId: item.itemId,
      nome: item.nome,
      quantidade: item.quantidade,
      precoUnitario: item.precoUnitario,
    );
  }
}
