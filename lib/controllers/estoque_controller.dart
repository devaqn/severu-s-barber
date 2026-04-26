import 'package:flutter/foundation.dart';

import '../models/movimento_estoque.dart';
import '../models/produto.dart';
import '../services/produto_service.dart';
import 'controller_mixin.dart';

class EstoqueController extends ChangeNotifier with ControllerMixin {
  EstoqueController({ProdutoService? produtoService})
      : _service = produtoService ?? ProdutoService();

  final ProdutoService _service;

  List<Produto> produtosEstoqueBaixo = [];
  List<MovimentoEstoque> movimentos = [];
  double valorTotalEstoque = 0;

  Future<void> carregar() => runSilent(() async {
        final results = await Future.wait([
          _service.getProdutosEstoqueBaixo(),
          _service.getMovimentos(),
          _service.getValorTotalEstoque(),
        ]);
        produtosEstoqueBaixo = results[0] as List<Produto>;
        movimentos = results[1] as List<MovimentoEstoque>;
        valorTotalEstoque = results[2] as double;
      });

  Future<void> registrarEntrada(
    int produtoId,
    int qtd,
    double valorUnitario,
  ) =>
      runOrThrow(() async {
        await _service.entradaEstoque(
          produtoId: produtoId,
          quantidade: qtd,
          valorUnitario: valorUnitario,
          observacao: 'Entrada manual via painel de estoque',
        );
        await carregar();
      });
}
