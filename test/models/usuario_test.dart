import 'package:barbearia_pro/models/usuario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap/toMap roundtrip preserva dados essenciais', () {
    final now = DateTime(2026, 4, 17, 10, 30);
    final original = Usuario(
      id: 'u1',
      nome: 'Admin',
      email: 'admin@teste.com',
      role: UserRole.admin,
      ativo: true,
      comissaoPercentual: 0,
      firstLogin: false,
      barbeariaId: 'shop_1',
      createdAt: now,
    );

    final map = original.toMap();
    final reconstruido = Usuario.fromMap(map);

    expect(reconstruido.id, original.id);
    expect(reconstruido.nome, original.nome);
    expect(reconstruido.role, UserRole.admin);
    expect(reconstruido.comissaoPercentual, 0);
    expect(reconstruido.barbeariaId, 'shop_1');
  });

  test('comissaoDecimal respeita escala 0..100 com clamp', () {
    final base = Usuario(
      id: 'u2',
      nome: 'Barbeiro',
      email: 'b@teste.com',
      role: UserRole.barbeiro,
      createdAt: DateTime(2026, 4, 17),
    );

    expect(base.copyWith(comissaoPercentual: 0).comissaoDecimal, 0);
    expect(base.copyWith(comissaoPercentual: 50).comissaoDecimal, 0.5);
    expect(base.copyWith(comissaoPercentual: 100).comissaoDecimal, 1);
    expect(base.copyWith(comissaoPercentual: 150).comissaoDecimal, 1);
  });

  test('igualdade e hashCode baseados no id', () {
    final a = Usuario(
      id: 'id_igual',
      nome: 'A',
      email: 'a@teste.com',
      role: UserRole.admin,
      createdAt: DateTime(2026, 4, 17),
    );
    final b = Usuario(
      id: 'id_igual',
      nome: 'B',
      email: 'b@teste.com',
      role: UserRole.barbeiro,
      createdAt: DateTime(2026, 4, 18),
    );

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });
}
