// ============================================================
// comissao_calculo_test.dart
// Testes da regra de negócio de comissão sem dependências externas.
//
// A lógica de _resolverComissaoPercentual converte valores
// da escala 0..100 (usuarios) ou 0..1 (servicos/produtos)
// para sempre retornar 0..1.
//
// Como o método é privado no ComandaService, os cálculos
// equivalentes são testados diretamente como função pura.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/item_comanda.dart';

// Replica exata da lógica de _resolverComissaoPercentual:
//   - Se > 1 assume escala 0..100 e divide por 100
//   - Clamp [0.0, 1.0]
double resolverComissaoPercentual(double raw, {double fallback = 0.0}) {
  final fb = fallback > 1 ? fallback / 100 : fallback;
  final escala = raw > 1 ? raw / 100 : raw;
  return escala.clamp(0.0, 1.0);
}

void main() {
  group('resolverComissaoPercentual', () {
    test('valor em escala 0..1 permanece inalterado', () {
      expect(resolverComissaoPercentual(0.40), closeTo(0.40, 0.0001));
    });

    test('valor em escala 0..100 é convertido para 0..1', () {
      expect(resolverComissaoPercentual(40.0), closeTo(0.40, 0.0001));
    });

    test('valor 0 → 0.0', () {
      expect(resolverComissaoPercentual(0), equals(0.0));
    });

    test('valor 100 → 1.0', () {
      expect(resolverComissaoPercentual(100), closeTo(1.0, 0.0001));
    });

    test('valor acima de 100 é clampado a 1.0', () {
      expect(resolverComissaoPercentual(150), closeTo(1.0, 0.0001));
    });

    test('valor negativo é clampado a 0.0', () {
      expect(resolverComissaoPercentual(-10), equals(0.0));
    });

    test('valor 1.0 permanece 1.0 (escala decimal)', () {
      // 1.0 <= 1, portanto não divide por 100
      expect(resolverComissaoPercentual(1.0), closeTo(1.0, 0.0001));
    });

    test('valor 50.0 (escala %) → 0.50 (escala decimal)', () {
      expect(resolverComissaoPercentual(50.0), closeTo(0.50, 0.0001));
    });
  });

  group('ItemComanda.comissaoValor com comissão resolvida', () {
    test('serviço R$80, 40% comissão → R$32 de comissão', () {
      final comissao = resolverComissaoPercentual(40.0); // 0.40
      final item = ItemComanda(
        tipo: 'servico',
        itemId: 1,
        nome: 'Corte',
        precoUnitario: 80.0,
        comissaoPercentual: comissao,
      );
      expect(item.comissaoValor, closeTo(32.0, 0.001));
      expect(item.lucroCasa, closeTo(48.0, 0.001));
    });

    test('produto R$30 × 3 unidades, 20% comissão → R$18 de comissão', () {
      final comissao = resolverComissaoPercentual(20.0); // 0.20
      final item = ItemComanda(
        tipo: 'produto',
        itemId: 2,
        nome: 'Pomada',
        quantidade: 3,
        precoUnitario: 30.0,
        comissaoPercentual: comissao,
      );
      expect(item.subtotal, closeTo(90.0, 0.001));
      expect(item.comissaoValor, closeTo(18.0, 0.001));
    });

    test('sem barbeiro (comissão 0) → casa fica com 100%', () {
      final item = ItemComanda(
        tipo: 'servico',
        itemId: 3,
        nome: 'Barba',
        precoUnitario: 40.0,
        comissaoPercentual: 0.0,
      );
      expect(item.comissaoValor, equals(0.0));
      expect(item.lucroCasa, closeTo(40.0, 0.001));
    });
  });

  group('Cálculo de comanda com múltiplos itens', () {
    test('soma total e comissão de uma comanda completa', () {
      final itens = [
        // Corte: R$80, 40% → comissão R$32
        ItemComanda(
          tipo: 'servico',
          itemId: 1,
          nome: 'Corte',
          precoUnitario: 80.0,
          comissaoPercentual: resolverComissaoPercentual(40),
        ),
        // Barba: R$40, 40% → comissão R$16
        ItemComanda(
          tipo: 'servico',
          itemId: 2,
          nome: 'Barba',
          precoUnitario: 40.0,
          comissaoPercentual: resolverComissaoPercentual(40),
        ),
        // Pomada: R$30 × 2, 20% → comissão R$12
        ItemComanda(
          tipo: 'produto',
          itemId: 3,
          nome: 'Pomada',
          quantidade: 2,
          precoUnitario: 30.0,
          comissaoPercentual: resolverComissaoPercentual(20),
        ),
      ];

      final total = itens.fold(0.0, (s, i) => s + i.subtotal);
      final comissao = itens.fold(0.0, (s, i) => s + i.comissaoValor);
      final lucro = total - comissao;

      // total: 80 + 40 + 60 = 180
      // comissão: 32 + 16 + 12 = 60
      // lucro: 180 - 60 = 120
      expect(total, closeTo(180.0, 0.001));
      expect(comissao, closeTo(60.0, 0.001));
      expect(lucro, closeTo(120.0, 0.001));
    });
  });
}
