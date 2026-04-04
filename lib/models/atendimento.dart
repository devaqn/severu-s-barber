// ============================================================
// atendimento.dart
// Model que representa um atendimento (visita) do cliente.
// Contém os itens (serviços e produtos), pagamento e data.
// ============================================================

/// Representa um item dentro de um atendimento (serviço ou produto)
class AtendimentoItem {
  final int? id;
  final int? atendimentoId;
  /// 'servico' ou 'produto'
  final String tipo;
  /// ID do serviço ou produto
  final int itemId;
  /// Nome salvo no momento do atendimento (histórico)
  final String nome;
  final int quantidade;
  final double precoUnitario;

  const AtendimentoItem({
    this.id,
    this.atendimentoId,
    required this.tipo,
    required this.itemId,
    required this.nome,
    this.quantidade = 1,
    required this.precoUnitario,
  });

  /// Subtotal do item
  double get subtotal => quantidade * precoUnitario;

  factory AtendimentoItem.fromMap(Map<String, dynamic> map) {
    return AtendimentoItem(
      id: map['id'] as int?,
      atendimentoId: map['atendimento_id'] as int?,
      tipo: map['tipo'] as String,
      itemId: map['item_id'] as int,
      nome: map['nome'] as String,
      quantidade: (map['quantidade'] as int?) ?? 1,
      precoUnitario: (map['preco_unitario'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (atendimentoId != null) 'atendimento_id': atendimentoId,
      'tipo': tipo,
      'item_id': itemId,
      'nome': nome,
      'quantidade': quantidade,
      'preco_unitario': precoUnitario,
    };
  }
}

/// Representa um atendimento completo na barbearia
class Atendimento {
  final int? id;
  final int? clienteId;
  /// Nome do cliente salvo no momento do atendimento
  final String clienteNome;
  final double total;
  final String formaPagamento;
  final DateTime data;
  final String? observacoes;
  /// Lista de itens (serviços + produtos) do atendimento
  final List<AtendimentoItem> itens;

  const Atendimento({
    this.id,
    this.clienteId,
    required this.clienteNome,
    required this.total,
    required this.formaPagamento,
    required this.data,
    this.observacoes,
    this.itens = const [],
  });

  factory Atendimento.fromMap(Map<String, dynamic> map) {
    return Atendimento(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int?,
      clienteNome: map['cliente_nome'] as String,
      total: (map['total'] as num).toDouble(),
      formaPagamento: map['forma_pagamento'] as String,
      data: DateTime.parse(map['data'] as String),
      observacoes: map['observacoes'] as String?,
      itens: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'cliente_nome': clienteNome,
      'total': total,
      'forma_pagamento': formaPagamento,
      'data': data.toIso8601String(),
      'observacoes': observacoes,
    };
  }

  Atendimento copyWith({
    int? id,
    int? clienteId,
    String? clienteNome,
    double? total,
    String? formaPagamento,
    DateTime? data,
    String? observacoes,
    List<AtendimentoItem>? itens,
  }) {
    return Atendimento(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      total: total ?? this.total,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      data: data ?? this.data,
      observacoes: observacoes ?? this.observacoes,
      itens: itens ?? this.itens,
    );
  }

  @override
  String toString() =>
      'Atendimento(id: $id, cliente: $clienteNome, total: $total)';
}
