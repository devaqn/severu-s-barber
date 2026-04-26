import 'package:flutter/foundation.dart';

import '../models/fornecedor.dart';
import '../models/movimento_estoque.dart';
import '../models/produto.dart';
import '../services/produto_service.dart';
import 'controller_mixin.dart';

class ProdutoController extends ChangeNotifier with ControllerMixin {
  ProdutoController({ProdutoService? produtoService})
      : _service = produtoService ?? ProdutoService();

  final ProdutoService _service;

  List<Produto> produtos = [];

  Future<List<Produto>> getAll({bool apenasAtivos = true}) async {
    final dados =
        await runCatch(() => _service.getAll(apenasAtivos: apenasAtivos));
    produtos = dados != null ? List<Produto>.from(dados) : const [];
    return produtos;
  }

  Future<Produto?> getById(int id) => runCatch(() => _service.getById(id));

  Future<double> getValorTotalEstoque() async =>
      await runCatch(() => _service.getValorTotalEstoque()) ?? 0.0;

  Future<List<Produto>> getProdutosEstoqueBaixo() async =>
      await runCatch(() => _service.getProdutosEstoqueBaixo()) ?? const [];

  Future<List<Produto>> getProdutosParados() async =>
      await runCatch(() => _service.getProdutosParados()) ?? const [];

  Future<List<Map<String, dynamic>>> getSugestoesReposicao() async =>
      await runCatch(() => _service.getSugestoesReposicao()) ?? const [];

  Future<List<MovimentoEstoque>> getMovimentos({int? produtoId}) async =>
      await runCatch(() => _service.getMovimentos(produtoId: produtoId)) ??
      const [];

  Future<List<Fornecedor>> getFornecedores() async =>
      await runCatch(() => _service.getFornecedores()) ?? const [];

  Future<void> entradaEstoque({
    required int produtoId,
    required int quantidade,
    required double valorUnitario,
    String? observacao,
  }) =>
      runOrThrow(() => _service.entradaEstoque(
            produtoId: produtoId,
            quantidade: quantidade,
            valorUnitario: valorUnitario,
            observacao: observacao,
          ));

  Future<int> insertFornecedor(Fornecedor fornecedor) =>
      runOrThrow(() => _service.insertFornecedor(fornecedor));

  Future<void> updateFornecedor(Fornecedor fornecedor) =>
      runOrThrow(() => _service.updateFornecedor(fornecedor));

  Future<void> deleteFornecedor(int id) =>
      runOrThrow(() => _service.deleteFornecedor(id));
}
