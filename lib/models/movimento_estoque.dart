// ============================================================
// movimento_estoque.dart
// Model que representa uma entrada ou saída de estoque.
// Mantém histórico completo de todas as movimentações.
// ============================================================

class MovimentoEstoque {
  final int? id;
  final int produtoId;
  /// Nome do produto salvo no momento do movimento
  final String produtoNome;
  /// 'entrada' ou 'saida'
  final String tipo;
  final int quantidade;
  /// Valor unitário no momento do movimento
  final double valorUnitario;
  final DateTime data;
  final String? observacao;

  const MovimentoEstoque({
    this.id,
    required this.produtoId,
    required this.produtoNome,
    required this.tipo,
    required this.quantidade,
    this.valorUnitario = 0.0,
    required this.data,
    this.observacao,
  });

  factory MovimentoEstoque.fromMap(Map<String, dynamic> map) {
    return MovimentoEstoque(
      id: map['id'] as int?,
      produtoId: map['produto_id'] as int,
      produtoNome: map['produto_nome'] as String,
      tipo: map['tipo'] as String,
      quantidade: map['quantidade'] as int,
      valorUnitario: (map['valor_unitario'] as num?)?.toDouble() ?? 0.0,
      data: DateTime.parse(map['data'] as String),
      observacao: map['observacao'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'produto_id': produtoId,
      'produto_nome': produtoNome,
      'tipo': tipo,
      'quantidade': quantidade,
      'valor_unitario': valorUnitario,
      'data': data.toIso8601String(),
      'observacao': observacao,
    };
  }

  /// Valor total do movimento
  double get valorTotal => quantidade * valorUnitario;

  bool get isEntrada => tipo == 'entrada';
  bool get isSaida => tipo == 'saida';

  @override
  String toString() =>
      'MovimentoEstoque(id: $id, produto: $produtoNome, tipo: $tipo, qtd: $quantidade)';
}
