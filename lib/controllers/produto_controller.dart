import 'package:flutter/foundation.dart';

import '../models/fornecedor.dart';
import '../models/movimento_estoque.dart';
import '../models/produto.dart';
import '../services/produto_service.dart';

class ProdutoController extends ChangeNotifier {
  ProdutoController({ProdutoService? produtoService})
      : _service = produtoService ?? ProdutoService();

  final ProdutoService _service;

  bool isLoading = false;
  String? errorMsg;
  List<Produto> produtos = [];

  Future<List<Produto>> getAll({bool apenasAtivos = true}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final dados = await _service.getAll(apenasAtivos: apenasAtivos);
      produtos = List<Produto>.from(dados);
      return dados;
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Produto>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Produto?> getById(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getById(id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<double> getValorTotalEstoque() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getValorTotalEstoque();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return 0;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Produto>> getProdutosEstoqueBaixo() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getProdutosEstoqueBaixo();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Produto>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Produto>> getProdutosParados() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getProdutosParados();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Produto>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getSugestoesReposicao() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getSugestoesReposicao();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Map<String, dynamic>>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<MovimentoEstoque>> getMovimentos({int? produtoId}) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getMovimentos(produtoId: produtoId);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <MovimentoEstoque>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Fornecedor>> getFornecedores() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.getFornecedores();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Fornecedor>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> entradaEstoque({
    required int produtoId,
    required int quantidade,
    required double valorUnitario,
    String? observacao,
  }) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.entradaEstoque(
        produtoId: produtoId,
        quantidade: quantidade,
        valorUnitario: valorUnitario,
        observacao: observacao,
      );
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<int> insertFornecedor(Fornecedor fornecedor) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.insertFornecedor(fornecedor);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateFornecedor(Fornecedor fornecedor) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.updateFornecedor(fornecedor);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteFornecedor(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.deleteFornecedor(id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
