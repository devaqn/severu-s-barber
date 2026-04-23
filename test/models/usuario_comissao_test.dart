// ============================================================
// usuario_comissao_test.dart
// Testes unitários focados em Usuario:
//   - fromMap / toMap / fromFirestore round-trips
//   - comissaoDecimal converte 0..100 → 0..1 corretamente
//   - roles: isAdmin / isBarbeiro
//   - copyWith sentinel para campos anuláveis
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/usuario.dart';

void main() {
  final createdAt = DateTime(2026, 1, 15, 9, 0);

  Usuario makeAdmin({
    String id = 'uid_admin',
    double comissao = 0.0,
  }) =>
      Usuario(
        id: id,
        nome: 'Admin Teste',
        email: 'admin@teste.com',
        role: UserRole.admin,
        ativo: true,
        comissaoPercentual: comissao,
        firstLogin: false,
        barbeariaId: 'shop_abc',
        createdAt: createdAt,
      );

  Usuario makeBarbeiro({
    String id = 'uid_barb',
    double comissao = 50.0,
    bool firstLogin = true,
    bool ativo = true,
  }) =>
      Usuario(
        id: id,
        nome: 'Carlos Barber',
        email: 'carlos@teste.com',
        telefone: '11999998888',
        role: UserRole.barbeiro,
        ativo: ativo,
        comissaoPercentual: comissao,
        firstLogin: firstLogin,
        barbeariaId: 'shop_abc',
        createdAt: createdAt,
      );

  // ─── comissaoDecimal ────────────────────────────────────────
  group('comissaoDecimal', () {
    test('50% → 0.50', () {
      expect(makeBarbeiro(comissao: 50).comissaoDecimal, closeTo(0.50, 0.001));
    });

    test('0% → 0.0', () {
      expect(makeAdmin(comissao: 0).comissaoDecimal, equals(0.0));
    });

    test('100% → 1.0', () {
      expect(makeBarbeiro(comissao: 100).comissaoDecimal, closeTo(1.0, 0.001));
    });

    test('clamp: valor > 100 é limitado a 1.0', () {
      // A lógica de clamp está em comissaoDecimal
      final u = Usuario(
        id: 'x',
        nome: 'X',
        email: 'x@x.com',
        role: UserRole.barbeiro,
        comissaoPercentual: 150,
        createdAt: createdAt,
      );
      expect(u.comissaoDecimal, equals(1.0));
    });

    test('valor negativo clampado a 0.0', () {
      final u = Usuario(
        id: 'x',
        nome: 'X',
        email: 'x@x.com',
        role: UserRole.barbeiro,
        comissaoPercentual: -10,
        createdAt: createdAt,
      );
      expect(u.comissaoDecimal, equals(0.0));
    });
  });

  // ─── roles ──────────────────────────────────────────────────
  group('roles', () {
    test('admin: isAdmin=true, isBarbeiro=false', () {
      final u = makeAdmin();
      expect(u.isAdmin, isTrue);
      expect(u.isBarbeiro, isFalse);
    });

    test('barbeiro: isAdmin=false, isBarbeiro=true', () {
      final u = makeBarbeiro();
      expect(u.isAdmin, isFalse);
      expect(u.isBarbeiro, isTrue);
    });

    test('UserRole.fromString com valor inválido retorna barbeiro', () {
      final role = UserRole.fromString('desconhecido');
      expect(role, equals(UserRole.barbeiro));
    });
  });

  // ─── fromMap / toMap ────────────────────────────────────────
  group('fromMap / toMap round-trip', () {
    test('admin: todos os campos preservados', () {
      final original = makeAdmin();
      final mapa = original.toMap();
      final reconstruido = Usuario.fromMap({
        ...mapa,
        'created_at': createdAt.toIso8601String(),
      });

      expect(reconstruido.id, equals(original.id));
      expect(reconstruido.nome, equals(original.nome));
      expect(reconstruido.email, equals(original.email));
      expect(reconstruido.role, equals(UserRole.admin));
      expect(reconstruido.ativo, isTrue);
      expect(reconstruido.firstLogin, isFalse);
      expect(reconstruido.comissaoPercentual, closeTo(0.0, 0.001));
    });

    test('barbeiro: comissao e firstLogin preservados', () {
      final original = makeBarbeiro(comissao: 35.0, firstLogin: true);
      final mapa = original.toMap();
      final reconstruido = Usuario.fromMap({
        ...mapa,
        'created_at': createdAt.toIso8601String(),
      });

      expect(reconstruido.role, equals(UserRole.barbeiro));
      expect(reconstruido.comissaoPercentual, closeTo(35.0, 0.001));
      expect(reconstruido.firstLogin, isTrue);
    });

    test('ativo como int (SQLite) é deserializado corretamente', () {
      final mapa = makeAdmin().toMap();
      // toMap() escreve ativo como 1 (int) para SQLite
      expect(mapa['ativo'], equals(1));
      final reconstruido =
          Usuario.fromMap({...mapa, 'created_at': createdAt.toIso8601String()});
      expect(reconstruido.ativo, isTrue);
    });

    test('ativo=false é serializado como 0', () {
      final u = makeBarbeiro(ativo: false);
      expect(u.toMap()['ativo'], equals(0));
    });
  });

  // ─── fromFirestore ──────────────────────────────────────────
  group('fromFirestore', () {
    test('ativo como bool (Firestore) é deserializado corretamente', () {
      final data = {
        'id': 'uid_barb',
        'nome': 'Carlos',
        'email': 'carlos@teste.com',
        'role': 'barbeiro',
        'ativo': true,
        'comissao_percentual': 45.0,
        'first_login': false,
        'barbearia_id': 'shop_x',
        'created_at': createdAt.toIso8601String(),
      };
      final u = Usuario.fromFirestore(data);
      expect(u.ativo, isTrue);
      expect(u.comissaoPercentual, closeTo(45.0, 0.001));
    });

    test('campos ausentes usam defaults seguros', () {
      final u = Usuario.fromFirestore({
        'id': 'uid_x',
        'nome': '',
        'email': '',
        'role': 'barbeiro',
      });
      expect(u.ativo, isTrue);       // default true
      expect(u.firstLogin, isFalse); // default false
      expect(u.comissaoPercentual, closeTo(50.0, 0.001)); // default
    });
  });

  // ─── copyWith ───────────────────────────────────────────────
  group('copyWith', () {
    test('alterar nome não afeta outros campos', () {
      final original = makeBarbeiro();
      final alterado = original.copyWith(nome: 'Novo Nome');
      expect(alterado.nome, equals('Novo Nome'));
      expect(alterado.email, equals(original.email));
      expect(alterado.role, equals(original.role));
      expect(alterado.comissaoPercentual,
          closeTo(original.comissaoPercentual, 0.001));
    });

    test('setar telefone para null usando sentinel', () {
      final original = makeBarbeiro();
      expect(original.telefone, isNotNull);
      final semTelefone = original.copyWith(telefone: null);
      expect(semTelefone.telefone, isNull);
    });

    test('igualdade por ID: mesmo id = mesmo objeto lógico', () {
      final a = makeAdmin(id: 'uid_shared');
      final b = makeBarbeiro(id: 'uid_shared');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
