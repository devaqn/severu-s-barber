// ============================================================
// estoque_controller.dart
// Controller para visao de estoque com ChangeNotifier.
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/movimento_estoque.dart';
import '../models/produto.dart';
import '../services/produto_service.dart';

/// Controller de estoque para consolidar dados da tela.
class EstoqueController extends ChangeNotifier {
  // Servico de produtos/estoque.
  final ProdutoService _service = ProdutoService();

  // Produtos com alerta de estoque baixo.
  List<Produto> produtosEstoqueBaixo = [];

  // Historico de movimentacoes de estoque.
  List<MovimentoEstoque> movimentos = [];

  // Valor total investido no estoque ativo.
  double valorTotalEstoque = 0;

  // Flag de carregamento da tela.
  bool isLoading = false;

  /// Carrega indicadores e listas de estoque em paralelo.
  Future<void> carregar() async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getProdutosEstoqueBaixo(),
        _service.getMovimentos(),
        _service.getValorTotalEstoque(),
      ]);
      produtosEstoqueBaixo = results[0] as List<Produto>;
      movimentos = results[1] as List<MovimentoEstoque>;
      valorTotalEstoque = results[2] as double;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Registra entrada manual e recarrega os dados da visao.
  Future<void> registrarEntrada(int produtoId, int qtd, double valorUnitario) async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.entradaEstoque(
        produtoId: produtoId,
        quantidade: qtd,
        valorUnitario: valorUnitario,
        observacao: 'Entrada manual via painel de estoque',
      );
      await carregar();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
