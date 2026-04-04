import '../database/database_helper.dart';
import '../models/comanda.dart';
import '../models/item_comanda.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'cliente_service.dart';
import 'produto_service.dart';
import 'service_exceptions.dart';

class ComandaService {
  final DatabaseHelper _db = DatabaseHelper();
  final ProdutoService _produtoService = ProdutoService();
  final ClienteService _clienteService = ClienteService();

  Future<List<Comanda>> getAll({String? barbeiroId, String? status}) async {
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    final safeStatus = status == null
        ? null
        : SecurityUtils.sanitizeEnumValue(
            status,
            fieldName: 'Status da comanda',
            allowedValues: const [
              AppConstants.comandaAberta,
              AppConstants.comandaFechada,
              AppConstants.comandaCancelada,
            ],
          );

    String? where;
    List<dynamic>? whereArgs;
    if (safeBarbeiroId != null && safeStatus != null) {
      where = 'barbeiro_id = ? AND status = ?';
      whereArgs = [safeBarbeiroId, safeStatus];
    } else if (safeBarbeiroId != null) {
      where = 'barbeiro_id = ?';
      whereArgs = [safeBarbeiroId];
    } else if (safeStatus != null) {
      where = 'status = ?';
      whereArgs = [safeStatus];
    }

    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_abertura DESC',
    );
    final comandas = maps.map((m) => Comanda.fromMap(m)).toList();
    return _anexarItens(comandas);
  }

  Future<Comanda?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: 'id = ?',
      whereArgs: [safeId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final comanda = Comanda.fromMap(maps.first);
    final itens = await _getItensByComandas([safeId]);
    return comanda.copyWith(itens: itens[safeId] ?? const []);
  }

  Future<Comanda?> getComandaAberta({String? barbeiroId}) async {
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );

    final where = safeBarbeiroId != null
        ? 'status = ? AND barbeiro_id = ?'
        : 'status = ?';
    final whereArgs = safeBarbeiroId != null
        ? [AppConstants.comandaAberta, safeBarbeiroId]
        : [AppConstants.comandaAberta];

    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final comanda = Comanda.fromMap(maps.first);
    final itens = await _getItensByComandas([comanda.id!]);
    return comanda.copyWith(itens: itens[comanda.id!] ?? const []);
  }

  Future<List<Comanda>> getComandasHoje({String? barbeiroId}) async {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
    final fim =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59).toIso8601String();

    var where = 'data_abertura BETWEEN ? AND ?';
    final whereArgs = <dynamic>[inicio, fim];

    if (barbeiroId != null) {
      final safeBarbeiroId = SecurityUtils.sanitizeIdentifier(
        barbeiroId,
        fieldName: 'ID do barbeiro',
        minLength: 1,
      );
      where += ' AND barbeiro_id = ?';
      whereArgs.add(safeBarbeiroId);
    }

    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_abertura DESC',
    );
    return maps.map((m) => Comanda.fromMap(m)).toList();
  }

  Future<Comanda> abrirComanda({
    int? clienteId,
    required String clienteNome,
    String? barbeiroId,
    String? barbeiroNome,
    String? observacoes,
  }) async {
    if (clienteId != null) {
      SecurityUtils.sanitizeIntRange(
        clienteId,
        fieldName: 'ID do cliente',
        min: 1,
        max: 1 << 30,
      );
    }
    final safeClienteNome = SecurityUtils.sanitizeName(
      clienteNome,
      fieldName: 'Nome do cliente',
    );
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    final safeBarbeiroNome = barbeiroNome == null
        ? null
        : SecurityUtils.sanitizeName(
            barbeiroNome,
            fieldName: 'Nome do barbeiro',
          );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    final comanda = Comanda(
      clienteId: clienteId,
      clienteNome: safeClienteNome,
      barbeiroId: safeBarbeiroId,
      barbeiroNome: safeBarbeiroNome,
      status: AppConstants.comandaAberta,
      dataAbertura: DateTime.now(),
      observacoes: safeObs,
    );

    final id = await _db.insert(AppConstants.tableComandas, comanda.toMap());
    return comanda.copyWith(id: id);
  }

  Future<void> adicionarItem(int comandaId, ItemComanda item) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final safeItem = _sanitizarItem(item);

    await _db.transaction((txn) async {
      final comandaRows = await txn.query(
        AppConstants.tableComandas,
        columns: ['id', 'status'],
        where: 'id = ?',
        whereArgs: [safeComandaId],
        limit: 1,
      );
      if (comandaRows.isEmpty) {
        throw const NotFoundException('Comanda nao encontrada.');
      }
      final status = comandaRows.first['status'] as String? ?? '';
      if (status != AppConstants.comandaAberta) {
        throw const ConflictException(
          'Nao e possivel adicionar itens em comanda fechada/cancelada.',
        );
      }

      await txn.insert(
        AppConstants.tableComandasItens,
        safeItem.copyWith(comandaId: safeComandaId).toMap(),
      );

      final totais = await _calcularTotaisComanda(txn, safeComandaId);
      await txn.update(
        AppConstants.tableComandas,
        {
          'total': totais.total,
          'comissao_total': totais.comissaoTotal,
        },
        where: 'id = ?',
        whereArgs: [safeComandaId],
      );
    });
  }

  Future<void> removerItem(int comandaId, int itemId) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final safeItemId = SecurityUtils.sanitizeIntRange(
      itemId,
      fieldName: 'ID do item',
      min: 1,
      max: 1 << 30,
    );

    await _db.transaction((txn) async {
      final comandaRows = await txn.query(
        AppConstants.tableComandas,
        columns: ['id', 'status'],
        where: 'id = ?',
        whereArgs: [safeComandaId],
        limit: 1,
      );
      if (comandaRows.isEmpty) {
        throw const NotFoundException('Comanda nao encontrada.');
      }
      final status = comandaRows.first['status'] as String? ?? '';
      if (status != AppConstants.comandaAberta) {
        throw const ConflictException(
          'Nao e possivel remover itens em comanda fechada/cancelada.',
        );
      }

      await txn.delete(
        AppConstants.tableComandasItens,
        where: 'id = ? AND comanda_id = ?',
        whereArgs: [safeItemId, safeComandaId],
      );

      final totais = await _calcularTotaisComanda(txn, safeComandaId);
      await txn.update(
        AppConstants.tableComandas,
        {
          'total': totais.total,
          'comissao_total': totais.comissaoTotal,
        },
        where: 'id = ?',
        whereArgs: [safeComandaId],
      );
    });
  }

  Future<void> fecharComanda({
    required int comandaId,
    required String formaPagamento,
    String? observacoes,
  }) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final safeFormaPagamento = SecurityUtils.sanitizeEnumValue(
      formaPagamento,
      fieldName: 'Forma de pagamento',
      allowedValues: AppConstants.formasPagamento,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    final agora = DateTime.now();
    await _db.transaction((txn) async {
      final comandaRows = await txn.query(
        AppConstants.tableComandas,
        where: 'id = ?',
        whereArgs: [safeComandaId],
        limit: 1,
      );
      if (comandaRows.isEmpty) {
        throw const NotFoundException('Comanda nao encontrada.');
      }

      final comanda = Comanda.fromMap(comandaRows.first);
      if (comanda.status != AppConstants.comandaAberta) {
        throw const ConflictException(
            'Comanda nao esta aberta para fechamento.');
      }

      final itensRows = await txn.query(
        AppConstants.tableComandasItens,
        where: 'comanda_id = ?',
        whereArgs: [safeComandaId],
        orderBy: 'id ASC',
      );
      final itens = itensRows.map((m) => ItemComanda.fromMap(m)).toList();
      if (itens.isEmpty) {
        throw const ValidationException(
          'Comanda sem itens nao pode ser fechada.',
        );
      }

      final total = itens.fold<double>(0, (s, i) => s + i.subtotal);
      final comissao = itens.fold<double>(0, (s, i) => s + i.comissaoValor);

      for (final item in itens) {
        if (item.tipo != 'produto') continue;
        await _produtoService.baixarEstoqueComExecutor(
          executor: txn,
          produtoId: item.itemId,
          quantidade: item.quantidade,
          valorUnitario: item.precoUnitario,
          observacao: 'Comanda #$safeComandaId',
        );
      }

      if (comanda.clienteId != null) {
        await _clienteService.atualizarAposAtendimento(
          comanda.clienteId!,
          total,
          executor: txn,
        );
      }

      final updatedRows = await txn.update(
        AppConstants.tableComandas,
        {
          'status': AppConstants.comandaFechada,
          'total': total,
          'comissao_total': comissao,
          'forma_pagamento': safeFormaPagamento,
          'data_fechamento': agora.toIso8601String(),
          if (safeObs != null) 'observacoes': safeObs,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [safeComandaId, AppConstants.comandaAberta],
      );
      if (updatedRows == 0) {
        throw const ConflictException(
          'Comanda foi alterada por outro processo.',
        );
      }

      if (comanda.barbeiroId != null && comissao > 0) {
        await txn.insert(AppConstants.tableComissoes, {
          'barbeiro_id': comanda.barbeiroId,
          'barbeiro_nome': comanda.barbeiroNome ?? 'Barbeiro',
          'comanda_id': safeComandaId,
          'valor': comissao,
          'data': agora.toIso8601String(),
          'status': 'pendente',
        });
      }
    });
  }

  Future<void> cancelarComanda(int comandaId) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final updated = await _db.update(
      AppConstants.tableComandas,
      {
        'status': AppConstants.comandaCancelada,
        'data_fechamento': DateTime.now().toIso8601String(),
      },
      'id = ? AND status = ?',
      [safeComandaId, AppConstants.comandaAberta],
    );
    if (updated == 0) {
      throw const ConflictException(
        'Somente comanda aberta pode ser cancelada.',
      );
    }
  }

  Future<double> getFaturamentoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final safeBarbeiroId = SecurityUtils.sanitizeIdentifier(
      barbeiroId,
      fieldName: 'ID do barbeiro',
      minLength: 1,
    );
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');

    final result = await _db.rawQuery('''
      SELECT SUM(total) as total
      FROM ${AppConstants.tableComandas}
      WHERE barbeiro_id = ?
        AND status = 'fechada'
        AND data_abertura BETWEEN ? AND ?
    ''', [safeBarbeiroId, inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getComissaoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final safeBarbeiroId = SecurityUtils.sanitizeIdentifier(
      barbeiroId,
      fieldName: 'ID do barbeiro',
      minLength: 1,
    );
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');

    final result = await _db.rawQuery('''
      SELECT SUM(valor) as total
      FROM ${AppConstants.tableComissoes}
      WHERE barbeiro_id = ?
        AND data BETWEEN ? AND ?
    ''', [safeBarbeiroId, inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getRankingBarbeiros(
    DateTime inicio,
    DateTime fim,
  ) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    return _db.rawQuery('''
      SELECT
        barbeiro_id,
        barbeiro_nome,
        COUNT(*) as total_comandas,
        SUM(total) as faturamento,
        SUM(comissao_total) as comissao
      FROM ${AppConstants.tableComandas}
      WHERE status = 'fechada'
        AND data_abertura BETWEEN ? AND ?
        AND barbeiro_id IS NOT NULL
      GROUP BY barbeiro_id
      ORDER BY faturamento DESC
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
  }

  Future<int> getCountComandasAbertas() async {
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as total FROM ${AppConstants.tableComandas}
      WHERE status = 'aberta'
    ''');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<Comanda>> _anexarItens(List<Comanda> comandas) async {
    if (comandas.isEmpty) return comandas;
    final ids = comandas.map((c) => c.id).whereType<int>().toList();
    final itensPorComanda = await _getItensByComandas(ids);

    return comandas
        .map((c) => c.copyWith(itens: itensPorComanda[c.id] ?? const []))
        .toList(growable: false);
  }

  Future<Map<int, List<ItemComanda>>> _getItensByComandas(
    List<int> comandaIds,
  ) async {
    if (comandaIds.isEmpty) return <int, List<ItemComanda>>{};

    final placeholders = List.filled(comandaIds.length, '?').join(', ');
    final rows = await _db.rawQuery('''
      SELECT *
      FROM ${AppConstants.tableComandasItens}
      WHERE comanda_id IN ($placeholders)
      ORDER BY id ASC
    ''', comandaIds);

    final result = <int, List<ItemComanda>>{};
    for (final row in rows) {
      final item = ItemComanda.fromMap(row);
      final comandaId = item.comandaId;
      if (comandaId == null) continue;
      (result[comandaId] ??= <ItemComanda>[]).add(item);
    }
    return result;
  }

  Future<_TotaisComanda> _calcularTotaisComanda(
    DatabaseExecutor txn,
    int comandaId,
  ) async {
    final rows = await txn.rawQuery('''
      SELECT 
        COALESCE(SUM(quantidade * preco_unitario), 0) as total,
        COALESCE(SUM(comissao_valor), 0) as comissao_total
      FROM ${AppConstants.tableComandasItens}
      WHERE comanda_id = ?
    ''', [comandaId]);

    final row = rows.first;
    return _TotaisComanda(
      total: (row['total'] as num?)?.toDouble() ?? 0.0,
      comissaoTotal: (row['comissao_total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ItemComanda _sanitizarItem(ItemComanda item) {
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
      fieldName: 'Quantidade',
      min: 1,
      max: 1000,
    );
    final safePrecoUnitario = SecurityUtils.sanitizeDoubleRange(
      item.precoUnitario,
      fieldName: 'Preco unitario',
      min: 0.01,
      max: 999999,
    );
    final safeComissao = SecurityUtils.sanitizeDoubleRange(
      item.comissaoPercentual,
      fieldName: 'Comissao',
      min: 0,
      max: 1,
    );

    return ItemComanda(
      id: item.id,
      comandaId: item.comandaId,
      tipo: safeTipo,
      itemId: safeItemId,
      nome: safeNome,
      quantidade: safeQuantidade,
      precoUnitario: safePrecoUnitario,
      comissaoPercentual: safeComissao,
    );
  }
}

class _TotaisComanda {
  final double total;
  final double comissaoTotal;
  const _TotaisComanda({
    required this.total,
    required this.comissaoTotal,
  });
}
