// ============================================================
// item_comanda.dart
// Model que representa um item dentro de uma comanda.
// Pode ser um serviço ou produto com cálculo de comissão.
// ============================================================

class ItemComanda {
  final int? id;
  final int? comandaId;
  /// 'servico' ou 'produto'
  final String tipo;
  /// ID do serviço ou produto referenciado
  final int itemId;
  /// Nome salvo no momento da comanda (histórico)
  final String nome;
  final int quantidade;
  final double precoUnitario;
  /// Percentual de comissão do barbeiro (0.0 a 1.0)
  final double comissaoPercentual;

  const ItemComanda({
    this.id,
    this.comandaId,
    required this.tipo,
    required this.itemId,
    required this.nome,
    this.quantidade = 1,
    required this.precoUnitario,
    this.comissaoPercentual = 0.0,
  });

  /// Subtotal do item
  double get subtotal => quantidade * precoUnitario;

  /// Valor de comissão do barbeiro neste item
  double get comissaoValor => subtotal * comissaoPercentual;

  /// Lucro da casa neste item (subtotal menos comissão)
  double get lucroCasa => subtotal - comissaoValor;

  factory ItemComanda.fromMap(Map<String, dynamic> map) {
    return ItemComanda(
      id: map['id'] as int?,
      comandaId: map['comanda_id'] as int?,
      tipo: map['tipo'] as String,
      itemId: map['item_id'] as int,
      nome: map['nome'] as String,
      quantidade: (map['quantidade'] as int?) ?? 1,
      precoUnitario: (map['preco_unitario'] as num).toDouble(),
      comissaoPercentual: (map['comissao_percentual'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (comandaId != null) 'comanda_id': comandaId,
      'tipo': tipo,
      'item_id': itemId,
      'nome': nome,
      'quantidade': quantidade,
      'preco_unitario': precoUnitario,
      'comissao_percentual': comissaoPercentual,
      'comissao_valor': comissaoValor,
    };
  }

  ItemComanda copyWith({int? id, int? comandaId}) {
    return ItemComanda(
      id: id ?? this.id,
      comandaId: comandaId ?? this.comandaId,
      tipo: tipo,
      itemId: itemId,
      nome: nome,
      quantidade: quantidade,
      precoUnitario: precoUnitario,
      comissaoPercentual: comissaoPercentual,
    );
  }
}
