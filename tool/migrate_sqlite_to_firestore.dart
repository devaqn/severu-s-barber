import 'dart:convert';
import 'dart:io';

import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _scopes = <String>[
  'https://www.googleapis.com/auth/datastore',
];

Future<void> main(List<String> args) async {
  final config = _Config.parse(args);
  sqfliteFfiInit();

  final db = await databaseFactoryFfi.openDatabase(config.sqlitePath);
  try {
    final writes = <fs.Write>[];
    final caixas = await _queryIfExists(db, 'caixas');
    final despesas = await _queryIfExists(db, 'despesas');
    final comandas = await _queryIfExists(db, 'comandas');
    final itens = await _queryIfExists(db, 'comandas_itens');

    final caixaIds = <int, String>{};
    for (final row in caixas) {
      final localId = (row['id'] as num).toInt();
      final docId = _docId(row, fallbackPrefix: 'caixa', localId: localId);
      caixaIds[localId] = docId;
      final operationIds = <String>[
        'migracao_valor_inicial_$localId',
        if (row['status'] == 'fechado') 'migracao_fechamento_$localId',
      ];
      writes.add(_write(
        config,
        'caixas/$docId',
        {
          ...row,
          'id': docId,
          'local_id': localId,
          'barbearia_id': config.barbeariaId,
          'operation_ids': operationIds,
          'migration_source': 'sqlite',
          'migration_version': 1,
        },
      ));
      writes.add(_write(
        config,
        'caixas/$docId/operacoes/migracao_valor_inicial_$localId',
        {
          'tipo': 'entrada',
          'valor': (row['valor_inicial'] as num?)?.toDouble() ?? 0.0,
          'timestamp': _utcIso(row['data_abertura']),
          'userId': row['created_by'],
          'operationId': 'migracao_valor_inicial_$localId',
          'barbearia_id': config.barbeariaId,
          'migration_source': 'sqlite',
        },
      ));
      if (row['status'] == 'fechado') {
        writes.add(_write(
          config,
          'caixas/$docId/operacoes/migracao_fechamento_$localId',
          {
            'tipo': 'fechamento',
            'valor': (row['valor_final'] as num?)?.toDouble() ?? 0.0,
            'timestamp': _utcIso(row['data_fechamento']),
            'userId': row['created_by'],
            'operationId': 'migracao_fechamento_$localId',
            'barbearia_id': config.barbeariaId,
            'migration_source': 'sqlite',
          },
        ));
      }
    }

    for (final row in despesas) {
      final localId = (row['id'] as num).toInt();
      final docId = _docId(row, fallbackPrefix: 'despesa', localId: localId);
      writes.add(_write(config, 'despesas/$docId', {
        ...row,
        'id': docId,
        'local_id': localId,
        'barbearia_id': config.barbeariaId,
        'data': _utcIso(row['data']),
        'migration_source': 'sqlite',
        'migration_version': 1,
      }));
      final caixaLocalId = _extractCaixaId(row['observacoes'] as String?);
      final caixaDocId = caixaLocalId == null ? null : caixaIds[caixaLocalId];
      if (caixaDocId != null) {
        final isReforco = ((row['valor'] as num?)?.toDouble() ?? 0) < 0;
        final operationId = 'migracao_despesa_$localId';
        writes.add(_write(config, 'caixas/$caixaDocId/operacoes/$operationId', {
          'tipo': isReforco ? 'reforco' : 'sangria',
          'valor': ((row['valor'] as num?)?.toDouble() ?? 0).abs(),
          'timestamp': _utcIso(row['data']),
          'userId': row['created_by'],
          'operationId': operationId,
          'barbearia_id': config.barbeariaId,
          'despesa_id': docId,
          'migration_source': 'sqlite',
        }));
      }
    }

    final itensPorComanda = <int, List<Map<String, Object?>>>{};
    for (final item in itens) {
      final comandaId = (item['comanda_id'] as num?)?.toInt();
      if (comandaId == null) continue;
      itensPorComanda.putIfAbsent(comandaId, () => []).add(item);
    }

    for (final row in comandas) {
      final localId = (row['id'] as num).toInt();
      final docId = _docId(row, fallbackPrefix: 'comanda', localId: localId);
      writes.add(_write(config, 'comandas/$docId', {
        ...row,
        'id': docId,
        'local_id': localId,
        'cliente_id': row['cliente_id']?.toString(),
        'barbearia_id': config.barbeariaId,
        'data_abertura': _utcIso(row['data_abertura']),
        'data_fechamento': _optionalUtcIso(row['data_fechamento']),
        'migration_source': 'sqlite',
        'migration_version': 1,
      }));
      for (final item in itensPorComanda[localId] ?? const []) {
        final itemLocalId = (item['id'] as num).toInt();
        final itemDocId =
            _docId(item, fallbackPrefix: 'item', localId: itemLocalId);
        writes.add(_write(config, 'comandas/$docId/itens/$itemDocId', {
          ...item,
          'id': itemDocId,
          'local_id': itemLocalId,
          'comanda_id': docId,
          'item_id': item['firebase_id'] ?? item['item_id'].toString(),
          'barbearia_id': config.barbeariaId,
          'migration_source': 'sqlite',
          'migration_version': 1,
        }));
      }
    }

    stdout.writeln('Prepared ${writes.length} Firestore writes.');
    if (config.dryRun) {
      stdout.writeln('Dry run enabled; no Firestore writes were sent.');
      return;
    }

    final credentials = ServiceAccountCredentials.fromJson(
      jsonDecode(await File(config.serviceAccountPath).readAsString())
          as Map<String, dynamic>,
    );
    final client = await clientViaServiceAccount(credentials, _scopes);
    try {
      final api = fs.FirestoreApi(client);
      final database = 'projects/${config.projectId}/databases/(default)';
      for (var i = 0; i < writes.length; i += 400) {
        final chunk = writes.skip(i).take(400).toList(growable: false);
        final response = await api.projects.databases.documents.batchWrite(
          fs.BatchWriteRequest(writes: chunk),
          database,
        );
        final failures =
            response.status?.where((s) => (s.code ?? 0) != 0).toList() ??
                const [];
        if (failures.isNotEmpty) {
          throw StateError('Firestore batch failed: ${failures.first.message}');
        }
        stdout.writeln('Wrote ${i + chunk.length}/${writes.length}');
      }
    } finally {
      client.close();
    }
  } finally {
    await db.close();
  }
}

fs.Write _write(_Config config, String path, Map<String, Object?> data) {
  return fs.Write(
    update: fs.Document(
      name:
          'projects/${config.projectId}/databases/(default)/documents/barbearias/${config.barbeariaId}/$path',
      fields: data.map((key, value) => MapEntry(key, _value(value))),
    ),
  );
}

fs.Value _value(Object? value) {
  if (value == null) return fs.Value(nullValue: 'NULL_VALUE');
  if (value is bool) return fs.Value(booleanValue: value);
  if (value is int) return fs.Value(integerValue: value.toString());
  if (value is double) return fs.Value(doubleValue: value);
  if (value is num) return fs.Value(doubleValue: value.toDouble());
  if (value is DateTime) {
    return fs.Value(timestampValue: value.toUtc().toIso8601String());
  }
  if (value is Iterable) {
    return fs.Value(
      arrayValue: fs.ArrayValue(
        values: value.map((entry) => _value(entry as Object?)).toList(),
      ),
    );
  }
  if (value is Map) {
    return fs.Value(
      mapValue: fs.MapValue(
        fields: value.map(
          (key, entry) => MapEntry(key.toString(), _value(entry as Object?)),
        ),
      ),
    );
  }
  return fs.Value(stringValue: value.toString());
}

Future<List<Map<String, Object?>>> _queryIfExists(
  Database db,
  String table,
) async {
  final exists = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [table],
  );
  if (exists.isEmpty) return const [];
  return db.query(table);
}

String _docId(
  Map<String, Object?> row, {
  required String fallbackPrefix,
  required int localId,
}) {
  final firebaseId = row['firebase_id'] as String?;
  if (firebaseId != null && firebaseId.trim().isNotEmpty) return firebaseId;
  return 'migracao_${fallbackPrefix}_$localId';
}

int? _extractCaixaId(String? observacoes) {
  if (observacoes == null) return null;
  return RegExp(r'Caixa #(\d+)')
      .firstMatch(observacoes)
      ?.group(1)
      ?.let(int.tryParse);
}

String _utcIso(Object? value) {
  return (_parseDate(value) ?? DateTime.now().toUtc())
      .toUtc()
      .toIso8601String();
}

String? _optionalUtcIso(Object? value) =>
    _parseDate(value)?.toUtc().toIso8601String();

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

extension _NullableStringLet on String {
  T? let<T>(T? Function(String value) fn) => fn(this);
}

class _Config {
  const _Config({
    required this.sqlitePath,
    required this.serviceAccountPath,
    required this.projectId,
    required this.barbeariaId,
    required this.dryRun,
  });

  final String sqlitePath;
  final String serviceAccountPath;
  final String projectId;
  final String barbeariaId;
  final bool dryRun;

  static _Config parse(List<String> args) {
    String? value(String name) {
      final index = args.indexOf('--$name');
      if (index == -1 || index + 1 >= args.length) return null;
      return args[index + 1];
    }

    final sqlitePath = value('db');
    final serviceAccountPath = value('service-account');
    final projectId = value('project');
    final barbeariaId = value('barbearia');
    final dryRun = args.contains('--dry-run');
    if (sqlitePath == null ||
        serviceAccountPath == null ||
        projectId == null ||
        barbeariaId == null) {
      stderr.writeln(
        'Usage: dart run tool/migrate_sqlite_to_firestore.dart '
        '--db <sqlite.db> --service-account <sa.json> '
        '--project <firebase-project-id> --barbearia <barbeariaId> '
        '[--dry-run]',
      );
      exitCode = 64;
      throw const FormatException('Missing required argument.');
    }
    return _Config(
      sqlitePath: sqlitePath,
      serviceAccountPath: serviceAccountPath,
      projectId: projectId,
      barbeariaId: barbeariaId,
      dryRun: dryRun,
    );
  }
}
