// ============================================================
// produto.dart
// Model que representa um produto vendido/usado na barbearia.
// Controla preço, custo, estoque, fornecedor e comissão.
// ============================================================

class Produto {
  final int? id;
  final String nome;

  /// Preço de venda ao cliente
  final double precoVenda;

  /// Preço de custo (compra do fornecedor)
  final double precoCusto;

  /// Quantidade atual em estoque
  final int quantidade;

  /// Estoque mínimo — abaixo disso gera alerta
  final int estoqueMinimo;

  /// Percentual de comissão do barbeiro (0.0 a 1.0)
  final double comissaoPercentual;

  /// ID do fornecedor (pode ser nulo)
  final int? fornecedorId;

  /// Nome do fornecedor (join para exibição)
  final String? fornecedorNome;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Produto({
    this.id,
    required this.nome,
    required this.precoVenda,
    this.precoCusto = 0.0,
    this.quantidade = 0,
    this.estoqueMinimo = 3,
    this.comissaoPercentual = 0.20,
    this.fornecedorId,
    this.fornecedorNome,
    this.ativo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Produto.fromMap(Map<String, dynamic> map) {
    final comissaoRaw =
        (map['comissao_percentual'] as num?)?.toDouble() ?? 0.20;
    final comissao = comissaoRaw > 1 ? comissaoRaw / 100 : comissaoRaw;
    return Produto(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      precoVenda: (map['preco_venda'] as num).toDouble(),
      precoCusto: (map['preco_custo'] as num?)?.toDouble() ?? 0.0,
      quantidade: (map['quantidade'] as int?) ?? 0,
      estoqueMinimo: (map['estoque_minimo'] as int?) ?? 3,
      comissaoPercentual: comissao.clamp(0.0, 1.0).toDouble(),
      fornecedorId: map['fornecedor_id'] as int?,
      fornecedorNome: map['fornecedor_nome'] as String?,
      ativo: (map['ativo'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'preco_venda': precoVenda,
      'preco_custo': precoCusto,
      'quantidade': quantidade,
      'estoque_minimo': estoqueMinimo,
      'comissao_percentual': comissaoPercentual,
      'fornecedor_id': fornecedorId,
      'ativo': ativo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Produto copyWith({
    int? id,
    String? nome,
    double? precoVenda,
    double? precoCusto,
    int? quantidade,
    int? estoqueMinimo,
    double? comissaoPercentual,
    int? fornecedorId,
    String? fornecedorNome,
    bool? ativo,
    DateTime? updatedAt,
  }) {
    return Produto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      precoVenda: precoVenda ?? this.precoVenda,
      precoCusto: precoCusto ?? this.precoCusto,
      quantidade: quantidade ?? this.quantidade,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      comissaoPercentual: comissaoPercentual ?? this.comissaoPercentual,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      fornecedorNome: fornecedorNome ?? this.fornecedorNome,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Margem de lucro em reais
  double get margemLucro => precoVenda - precoCusto;

  /// Margem de lucro em percentual
  double get margemLucroPercent =>
      precoCusto > 0 ? (margemLucro / precoCusto) : 0;

  /// Se o estoque está abaixo do mínimo
  bool get estoqueBaixo => quantidade <= estoqueMinimo;

  /// Valor total do estoque deste produto (custo)
  double get valorEstoque => quantidade * precoCusto;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Produto) return false;
    if (id != null && other.id != null) return other.id == id;
    return other.nome == nome &&
        other.precoVenda == precoVenda &&
        other.quantidade == quantidade;
  }

  @override
  int get hashCode => id?.hashCode ?? Object.hash(nome, precoVenda, quantidade);

  @override
  String toString() => 'Produto(id: $id, nome: $nome, qtd: $quantidade)';
}
