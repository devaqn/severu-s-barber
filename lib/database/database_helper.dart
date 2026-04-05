// ============================================================
// database_helper.dart
// Core SQLite helper for schema, indexes and generic CRUD.
// ============================================================

import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static String? _overrideDbName;
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await _resolveDatabasePath();
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await _createIndexes(db);
      },
    );
  }

  Future<String> _resolveDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _overrideDbName ?? AppConstants.dbName);
  }

  static Future<void> setDatabaseNameForTests(String? dbName) async {
    _overrideDbName = dbName;
    await _instance.close();
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _createIndexes(db);
    await _insertDefaultData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTablesV2(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }
    await _createIndexes(db);
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableClientes} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        nome TEXT NOT NULL,
        telefone TEXT NOT NULL,
        observacoes TEXT,
        data_nascimento TEXT,
        total_gasto REAL DEFAULT 0.0,
        ultima_visita TEXT,
        pontos_fidelidade INTEGER DEFAULT 0,
        total_atendimentos INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableServicos} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        nome TEXT NOT NULL,
        preco REAL NOT NULL,
        duracao_minutos INTEGER DEFAULT 30,
        comissao_percentual REAL DEFAULT 0.50,
        ativo INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableFornecedores} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        telefone TEXT,
        email TEXT,
        observacoes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableProdutos} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        nome TEXT NOT NULL,
        preco_venda REAL NOT NULL,
        preco_custo REAL DEFAULT 0.0,
        quantidade INTEGER DEFAULT 0,
        estoque_minimo INTEGER DEFAULT 3,
        comissao_percentual REAL DEFAULT 0.20,
        fornecedor_id INTEGER,
        ativo INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (fornecedor_id) REFERENCES ${AppConstants.tableFornecedores}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableAtendimentos} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        cliente_id INTEGER,
        cliente_nome TEXT NOT NULL,
        barbeiro_id TEXT,
        barbeiro_nome TEXT,
        total REAL NOT NULL,
        comissao_total REAL DEFAULT 0.0,
        forma_pagamento TEXT NOT NULL,
        data TEXT NOT NULL,
        observacoes TEXT,
        FOREIGN KEY (cliente_id) REFERENCES ${AppConstants.tableClientes}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableAtendimentoItens} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        atendimento_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        nome TEXT NOT NULL,
        quantidade INTEGER DEFAULT 1,
        preco_unitario REAL NOT NULL,
        comissao_percentual REAL DEFAULT 0.0,
        comissao_valor REAL DEFAULT 0.0,
        FOREIGN KEY (atendimento_id) REFERENCES ${AppConstants.tableAtendimentos}(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableAgendamentos} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        cliente_id INTEGER,
        cliente_nome TEXT NOT NULL,
        servico_id INTEGER,
        servico_nome TEXT NOT NULL,
        barbeiro_id TEXT,
        barbeiro_nome TEXT,
        data_hora TEXT NOT NULL,
        status TEXT DEFAULT 'Pendente',
        observacoes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (cliente_id) REFERENCES ${AppConstants.tableClientes}(id),
        FOREIGN KEY (servico_id) REFERENCES ${AppConstants.tableServicos}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableDespesas} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        descricao TEXT NOT NULL,
        categoria TEXT NOT NULL,
        valor REAL NOT NULL,
        data TEXT NOT NULL,
        observacoes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableMovimentosEstoque} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        produto_id INTEGER NOT NULL,
        produto_nome TEXT NOT NULL,
        tipo TEXT NOT NULL,
        quantidade INTEGER NOT NULL,
        valor_unitario REAL DEFAULT 0.0,
        data TEXT NOT NULL,
        observacao TEXT,
        updated_at TEXT,
        FOREIGN KEY (produto_id) REFERENCES ${AppConstants.tableProdutos}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCaixas} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        data_abertura TEXT NOT NULL,
        data_fechamento TEXT,
        valor_inicial REAL DEFAULT 0.0,
        valor_final REAL,
        status TEXT DEFAULT 'aberto',
        resumo_pagamentos TEXT,
        observacoes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await _createTablesV2(db);
  }

  Future<void> _createTablesV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableUsuarios} (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        email TEXT NOT NULL,
        telefone TEXT,
        photo_url TEXT,
        barbearia_id TEXT,
        role TEXT NOT NULL DEFAULT 'barbeiro',
        ativo INTEGER DEFAULT 1,
        comissao_percentual REAL DEFAULT 50.0,
        first_login INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableComandas} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        cliente_id INTEGER,
        cliente_nome TEXT NOT NULL,
        barbeiro_id TEXT,
        barbeiro_nome TEXT,
        barbeiro_uid TEXT,
        status TEXT DEFAULT 'aberta',
        total REAL DEFAULT 0.0,
        comissao_total REAL DEFAULT 0.0,
        forma_pagamento TEXT,
        data_abertura TEXT NOT NULL,
        data_fechamento TEXT,
        observacoes TEXT,
        updated_at TEXT,
        FOREIGN KEY (cliente_id) REFERENCES ${AppConstants.tableClientes}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableComandasItens} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        comanda_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        nome TEXT NOT NULL,
        quantidade INTEGER DEFAULT 1,
        preco_unitario REAL NOT NULL,
        comissao_percentual REAL DEFAULT 0.0,
        comissao_valor REAL DEFAULT 0.0,
        updated_at TEXT,
        FOREIGN KEY (comanda_id) REFERENCES ${AppConstants.tableComandas}(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableComissoes} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        barbearia_id TEXT,
        created_by TEXT,
        barbeiro_id TEXT NOT NULL,
        barbeiro_nome TEXT NOT NULL,
        comanda_id INTEGER,
        atendimento_id INTEGER,
        valor REAL NOT NULL,
        data TEXT NOT NULL,
        status TEXT DEFAULT 'pendente',
        observacao TEXT
      )
    ''');
  }

  Future<void> _migrateToV3(Database db) async {
    await _addColumnIfMissing(
      db,
      AppConstants.tableClientes,
      'data_nascimento',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableUsuarios,
      'telefone',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableUsuarios,
      'first_login',
      'INTEGER DEFAULT 0',
    );

    // Converte bases antigas que salvavam 0.50 para a escala atual (50.0).
    await db.execute('''
      UPDATE ${AppConstants.tableUsuarios}
      SET comissao_percentual = comissao_percentual * 100
      WHERE comissao_percentual IS NOT NULL
        AND comissao_percentual > 0
        AND comissao_percentual <= 1
    ''');
  }

  Future<void> _migrateToV4(Database db) async {
    await _addColumnIfMissing(
      db,
      AppConstants.tableUsuarios,
      'barbearia_id',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableClientes,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableClientes,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableClientes,
      'created_by',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableServicos,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableServicos,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableServicos,
      'created_by',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableServicos,
      'created_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableServicos,
      'updated_at',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableProdutos,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableProdutos,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableProdutos,
      'created_by',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableAtendimentos,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableAtendimentos,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableAtendimentos,
      'created_by',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableAgendamentos,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableAgendamentos,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableAgendamentos,
      'created_by',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableAgendamentos,
      'updated_at',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableDespesas,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableDespesas,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableDespesas,
      'created_by',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableDespesas,
      'created_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableDespesas,
      'updated_at',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableMovimentosEstoque,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableMovimentosEstoque,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableMovimentosEstoque,
      'created_by',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableMovimentosEstoque,
      'updated_at',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableCaixas,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableCaixas,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableCaixas,
      'created_by',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableCaixas,
      'created_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableCaixas,
      'updated_at',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableComandas,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComandas,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComandas,
      'created_by',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComandas,
      'barbeiro_uid',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComandas,
      'updated_at',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableComandasItens,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComandasItens,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComandasItens,
      'created_by',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComandasItens,
      'updated_at',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      AppConstants.tableComissoes,
      'firebase_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComissoes,
      'barbearia_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      AppConstants.tableComissoes,
      'created_by',
      'TEXT',
    );
  }

  Future<void> _migrateToV5(Database db) async {
    await _addColumnIfMissing(
      db,
      AppConstants.tableUsuarios,
      'photo_url',
      'TEXT',
    );

    await db.execute('''
      UPDATE ${AppConstants.tableServicos}
      SET comissao_percentual = comissao_percentual / 100.0
      WHERE comissao_percentual IS NOT NULL
        AND comissao_percentual > 1
        AND comissao_percentual <= 100
    ''');

    await db.execute('''
      UPDATE ${AppConstants.tableProdutos}
      SET comissao_percentual = comissao_percentual / 100.0
      WHERE comissao_percentual IS NOT NULL
        AND comissao_percentual > 1
        AND comissao_percentual <= 100
    ''');
  }

  Future<void> _migrateToV6(Database db) async {
    await db.execute('''
      UPDATE ${AppConstants.tableProdutos}
      SET fornecedor_id = NULL
      WHERE fornecedor_id IN (
        SELECT id
        FROM ${AppConstants.tableFornecedores}
        WHERE nome = 'Distribuidora Beauty Pro'
      )
    ''');

    await db.execute('''
      DELETE FROM ${AppConstants.tableFornecedores}
      WHERE nome = 'Distribuidora Beauty Pro'
    ''');
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = info.any((row) => row['name'] == columnName);
    if (exists) return;
    await db.execute(
      'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
    );
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_clientes_nome
      ON ${AppConstants.tableClientes}(nome)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_firebase_unique
      ON ${AppConstants.tableClientes}(firebase_id)
      WHERE firebase_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_atendimentos_data
      ON ${AppConstants.tableAtendimentos}(data)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_atendimentos_cliente
      ON ${AppConstants.tableAtendimentos}(cliente_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_atendimento_itens_atendimento
      ON ${AppConstants.tableAtendimentoItens}(atendimento_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_agendamentos_data_status
      ON ${AppConstants.tableAgendamentos}(data_hora, status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_produtos_ativo_nome
      ON ${AppConstants.tableProdutos}(ativo, nome)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_produtos_firebase_unique
      ON ${AppConstants.tableProdutos}(firebase_id)
      WHERE firebase_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_servicos_firebase_unique
      ON ${AppConstants.tableServicos}(firebase_id)
      WHERE firebase_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movimentos_produto_data
      ON ${AppConstants.tableMovimentosEstoque}(produto_id, data)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movimentos_tipo_data
      ON ${AppConstants.tableMovimentosEstoque}(tipo, data)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_despesas_data_categoria
      ON ${AppConstants.tableDespesas}(data, categoria)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_despesas_firebase_unique
      ON ${AppConstants.tableDespesas}(firebase_id)
      WHERE firebase_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_usuarios_email_unique
      ON ${AppConstants.tableUsuarios}(email)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_comandas_status_data
      ON ${AppConstants.tableComandas}(status, data_abertura)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_comandas_firebase_unique
      ON ${AppConstants.tableComandas}(firebase_id)
      WHERE firebase_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_comandas_barbeiro_status
      ON ${AppConstants.tableComandas}(barbeiro_id, status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_comandas_itens_comanda
      ON ${AppConstants.tableComandasItens}(comanda_id)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_agendamentos_firebase_unique
      ON ${AppConstants.tableAgendamentos}(firebase_id)
      WHERE firebase_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_comissoes_barbeiro_data
      ON ${AppConstants.tableComissoes}(barbeiro_id, data)
    ''');
  }

  Future<void> _insertDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final servicos = [
      {
        'nome': 'Corte de Cabelo',
        'preco': 35.0,
        'duracao_minutos': 30,
        'comissao_percentual': 0.50,
        'ativo': 1
      },
      {
        'nome': 'Barba',
        'preco': 25.0,
        'duracao_minutos': 20,
        'comissao_percentual': 0.50,
        'ativo': 1
      },
      {
        'nome': 'Corte + Barba',
        'preco': 55.0,
        'duracao_minutos': 50,
        'comissao_percentual': 0.50,
        'ativo': 1
      },
      {
        'nome': 'Sobrancelha',
        'preco': 15.0,
        'duracao_minutos': 15,
        'comissao_percentual': 0.50,
        'ativo': 1
      },
      {
        'nome': 'Lavagem',
        'preco': 20.0,
        'duracao_minutos': 20,
        'comissao_percentual': 0.50,
        'ativo': 1
      },
      {
        'nome': 'Hidratacao',
        'preco': 30.0,
        'duracao_minutos': 25,
        'comissao_percentual': 0.50,
        'ativo': 1
      },
      {
        'nome': 'Relaxamento',
        'preco': 45.0,
        'duracao_minutos': 40,
        'comissao_percentual': 0.50,
        'ativo': 1
      },
    ];

    for (final s in servicos) {
      await db.insert(AppConstants.tableServicos, s);
    }

    await db.insert(AppConstants.tableUsuarios, {
      'id': 'admin_local',
      'nome': 'Administrador',
      'email': 'admin@severusbarber.com',
      'telefone': null,
      'photo_url': null,
      'barbearia_id': AppConstants.localBarbeariaId,
      'role': AppConstants.roleAdmin,
      'ativo': 1,
      'comissao_percentual': 0.0,
      'first_login': 0,
      'created_at': now,
    });
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> queryAll(
    String table, {
    String? orderBy,
    String? where,
    List<dynamic>? whereArgs,
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      table,
      orderBy: orderBy,
      where: where,
      whereArgs: whereArgs,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<void> rawExecute(String sql, [List<dynamic>? args]) async {
    final db = await database;
    await db.execute(sql, args);
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> resetForTests({bool seedDefaultData = true}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      final tabelas = <String>[
        AppConstants.tableComandasItens,
        AppConstants.tableComissoes,
        AppConstants.tableComandas,
        AppConstants.tableAtendimentoItens,
        AppConstants.tableAtendimentos,
        AppConstants.tableMovimentosEstoque,
        AppConstants.tableAgendamentos,
        AppConstants.tableDespesas,
        AppConstants.tableCaixas,
        AppConstants.tableProdutos,
        AppConstants.tableFornecedores,
        AppConstants.tableServicos,
        AppConstants.tableClientes,
        AppConstants.tableUsuarios,
      ];

      for (final tabela in tabelas) {
        await txn.delete(tabela);
      }
      await txn.execute('DELETE FROM sqlite_sequence');
      await txn.execute('PRAGMA foreign_keys = ON');
    });

    if (seedDefaultData) {
      await _insertDefaultData(db);
    }
  }

  Future<void> deleteDatabaseFile() async {
    await close();
    final path = await _resolveDatabasePath();
    await databaseFactory.deleteDatabase(path);
  }
}
