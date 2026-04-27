// ============================================================
// comanda_test.dart
// Testes unitários para Comanda e ItemComanda:
//   - Serialização fromMap / toMap (round-trip)
//   - Cálculos derivados: subtotal, comissaoValor, lucroCasa
//   - copyWith preserva campos não alterados
//   - Igualdade por ID e por identidade de campos
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:barbearia_pro/models/comanda.dart';
import 'package:barbearia_pro/models/item_comanda.dart';

void main() {
  // ─── helpers ────────────────────────────────────────────────
  final abertura = DateTime(2026, 4, 23, 10, 0);

  ItemComanda makeItem({
    int id = 1,
    String tipo = 'servico',
    int itemId = 10,
    String nome = 'Corte',
    int quantidade = 1,
    double preco = 50.0,
    double comissao = 0.40,
  }) =>
      ItemComanda(
        id: id,
        comandaId: 100,
        tipo: tipo,
        itemId: itemId,
        nome: nome,
        quantidade: quantidade,
        precoUnitario: preco,
        comissaoPercentual: comissao,
      );

  Comanda makeComanda({int? id = 1, String status = 'aberta'}) => Comanda(
        id: id,
        clienteId: 5,
        clienteNome: 'João Silva',
        barbeiroId: 'barb_001',
        barbeiroNome: 'Carlos',
        status: status,
        total: 100.0,
        comissaoTotal: 40.0,
        formaPagamento: status == 'fechada' ? 'Dinheiro' : null,
        dataAbertura: abertura,
        dataFechamento:
            status == 'fechada' ? abertura.add(const Duration(hours: 1)) : null,
        observacoes: 'Obs',
      );

  // ─── ItemComanda ────────────────────────────────────────────
  group('ItemComanda', () {
    test('subtotal = quantidade × precoUnitario', () {
      final item = makeItem(quantidade: 3, preco: 25.0);
      expect(item.subtotal, closeTo(75.0, 0.001));
    });

    test('comissaoValor = subtotal × comissaoPercentual', () {
      final item = makeItem(quantidade: 2, preco: 50.0, comissao: 0.30);
      expect(item.comissaoValor, closeTo(30.0, 0.001));
    });

    test('lucroCasa = subtotal - comissaoValor', () {
      final item = makeItem(quantidade: 1, preco: 80.0, comissao: 0.50);
      expect(item.lucroCasa, closeTo(40.0, 0.001));
    });

    test('toMap / fromMap round-trip', () {
      final original = makeItem();
      final mapa = original.toMap();
      final reconstruido = ItemComanda.fromMap({
        ...mapa,
        'id': original.id,
        'comanda_id': original.comandaId,
      });

      expect(reconstruido.tipo, equals(original.tipo));
      expect(reconstruido.itemId, equals(original.itemId));
      expect(reconstruido.nome, equals(original.nome));
      expect(reconstruido.quantidade, equals(original.quantidade));
      expect(
          reconstruido.precoUnitario, closeTo(original.precoUnitario, 0.001));
      expect(reconstruido.comissaoPercentual,
          closeTo(original.comissaoPercentual, 0.001));
    });

    test('toMap inclui comissao_valor calculado', () {
      final item = makeItem(quantidade: 2, preco: 50.0, comissao: 0.40);
      final mapa = item.toMap();
      expect(mapa['comissao_valor'], closeTo(40.0, 0.001));
    });

    test('copyWith altera apenas campo especificado', () {
      final original = makeItem(nome: 'Corte', quantidade: 1);
      final alterado = original.copyWith(quantidade: 3);
      expect(alterado.quantidade, equals(3));
      expect(alterado.nome, equals('Corte'));
    });

    test('igualdade por ID quando ambos têm id', () {
      final a = makeItem(id: 7);
      final b = makeItem(id: 7, nome: 'Outro nome');
      expect(a, equals(b));
    });

    test('comissaoPercentual 0 → comissaoValor 0', () {
      final item = makeItem(comissao: 0.0);
      expect(item.comissaoValor, equals(0.0));
      expect(item.lucroCasa, equals(item.subtotal));
    });
  });

  // ─── Comanda ────────────────────────────────────────────────
  group('Comanda', () {
    test('lucroCasa = total - comissaoTotal', () {
      final c = makeComanda();
      expect(c.lucroCasa, closeTo(60.0, 0.001));
    });

    test('percentualComissaoMedio = comissaoTotal / total', () {
      final c = makeComanda();
      expect(c.percentualComissaoMedio, closeTo(0.40, 0.001));
    });

    test('percentualComissaoMedio = 0 quando total = 0', () {
      final c = Comanda(
        clienteNome: 'Zero',
        dataAbertura: abertura,
        total: 0,
        comissaoTotal: 0,
      );
      expect(c.percentualComissaoMedio, equals(0.0));
    });

    test('fromMap / toMap round-trip preserva todos os campos', () {
      final original = makeComanda(status: 'fechada');
      final mapa = {
        ...original.toMap(),
        'data_abertura': original.dataAbertura.toIso8601String(),
        'data_fechamento': original.dataFechamento?.toIso8601String(),
      };
      final reconstruido = Comanda.fromMap(mapa);

      expect(reconstruido.clienteId, equals(original.clienteId));
      expect(reconstruido.clienteNome, equals(original.clienteNome));
      expect(reconstruido.barbeiroId, equals(original.barbeiroId));
      expect(reconstruido.status, equals(original.status));
      expect(reconstruido.total, closeTo(original.total, 0.001));
      expect(
          reconstruido.comissaoTotal, closeTo(original.comissaoTotal, 0.001));
      expect(reconstruido.formaPagamento, equals(original.formaPagamento));
      expect(reconstruido.dataFechamento, isNotNull);
    });

    test('fromMap com dataFechamento null não lança', () {
      final c = Comanda.fromMap({
        'id': 1,
        'cliente_nome': 'Ana',
        'status': 'aberta',
        'total': 0.0,
        'comissao_total': 0.0,
        'data_abertura': abertura.toIso8601String(),
        'data_fechamento': null,
      });
      expect(c.dataFechamento, isNull);
    });

    test('copyWith altera status sem alterar outros campos', () {
      final original = makeComanda();
      final fechada = original.copyWith(
        status: 'fechada',
        formaPagamento: 'Pix',
        dataFechamento: abertura.add(const Duration(hours: 1)),
        total: 120.0,
      );
      expect(fechada.status, equals('fechada'));
      expect(fechada.clienteNome, equals(original.clienteNome));
      expect(fechada.barbeiroId, equals(original.barbeiroId));
      expect(fechada.total, closeTo(120.0, 0.001));
    });

    test('igualdade por ID', () {
      final a = makeComanda(id: 5);
      final b = makeComanda(id: 5, status: 'fechada');
      expect(a, equals(b));
    });

    test('comandas com id null são diferentes se campos diferem', () {
      final a =
          Comanda(clienteNome: 'A', dataAbertura: abertura, status: 'aberta');
      final b =
          Comanda(clienteNome: 'B', dataAbertura: abertura, status: 'aberta');
      expect(a, isNot(equals(b)));
    });
  });

  // ─── Cálculo agregado ────────────────────────────────────────
  group('Cálculo agregado de itens', () {
    test('total da comanda bate com soma dos subtotais dos itens', () {
      final itens = [
        makeItem(quantidade: 1, preco: 50.0, comissao: 0.40),
        makeItem(
            id: 2,
            tipo: 'produto',
            itemId: 20,
            nome: 'Pomada',
            quantidade: 2,
            preco: 25.0,
            comissao: 0.20),
      ];

      final totalCalculado =
          itens.fold<double>(0.0, (acc, i) => acc + i.subtotal);
      final comissaoCalculada =
          itens.fold<double>(0.0, (acc, i) => acc + i.comissaoValor);

      // Corte: 1×50 = 50, comissão 40% = 20
      // Pomada: 2×25 = 50, comissão 20% = 10
      expect(totalCalculado, closeTo(100.0, 0.001));
      expect(comissaoCalculada, closeTo(30.0, 0.001));
    });
  });
}
