// ============================================================
// comanda.dart
// Model que representa uma comanda de atendimento.
// Contém itens, barbeiro, cliente e cálculo de comissão.
// ============================================================

import 'item_comanda.dart';

class Comanda {
  final int? id;
  final int? clienteId;

  /// Nome do cliente salvo no momento da abertura
  final String clienteNome;

  /// ID do barbeiro no Firebase Auth / local
  final String? barbeiroId;

  /// Nome do barbeiro salvo no momento da abertura
  final String? barbeiroNome;

  /// 'aberta', 'fechada' ou 'cancelada'
  final String status;
  final double total;

  /// Total de comissão calculado somando todos os itens
  final double comissaoTotal;
  final String? formaPagamento;
  final DateTime dataAbertura;
  final DateTime? dataFechamento;
  final String? observacoes;

  /// Itens da comanda (serviços e produtos)
  final List<ItemComanda> itens;

  const Comanda({
    this.id,
    this.clienteId,
    required this.clienteNome,
    this.barbeiroId,
    this.barbeiroNome,
    this.status = 'aberta',
    this.total = 0.0,
    this.comissaoTotal = 0.0,
    this.formaPagamento,
    required this.dataAbertura,
    this.dataFechamento,
    this.observacoes,
    this.itens = const [],
  });

  /// Lucro da casa (total - comissão)
  double get lucroCasa => total - comissaoTotal;

  /// Percentual de comissão médio da comanda
  double get percentualComissaoMedio => total > 0 ? (comissaoTotal / total) : 0;

  factory Comanda.fromMap(Map<String, dynamic> map) {
    return Comanda(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int?,
      clienteNome: map['cliente_nome'] as String,
      barbeiroId: map['barbeiro_id'] as String?,
      barbeiroNome: map['barbeiro_nome'] as String?,
      status: (map['status'] as String?) ?? 'aberta',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      comissaoTotal: (map['comissao_total'] as num?)?.toDouble() ?? 0.0,
      formaPagamento: map['forma_pagamento'] as String?,
      dataAbertura: DateTime.parse(map['data_abertura'] as String),
      dataFechamento: map['data_fechamento'] != null
          ? DateTime.parse(map['data_fechamento'] as String)
          : null,
      observacoes: map['observacoes'] as String?,
      itens: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'cliente_nome': clienteNome,
      'barbeiro_id': barbeiroId,
      'barbeiro_nome': barbeiroNome,
      'status': status,
      'total': total,
      'comissao_total': comissaoTotal,
      'forma_pagamento': formaPagamento,
      'data_abertura': dataAbertura.toIso8601String(),
      'data_fechamento': dataFechamento?.toIso8601String(),
      'observacoes': observacoes,
    };
  }

  Comanda copyWith({
    int? id,
    int? clienteId,
    String? clienteNome,
    String? status,
    double? total,
    double? comissaoTotal,
    String? formaPagamento,
    DateTime? dataAbertura,
    DateTime? dataFechamento,
    String? observacoes,
    List<ItemComanda>? itens,
    String? barbeiroId,
    String? barbeiroNome,
  }) {
    return Comanda(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      barbeiroId: barbeiroId ?? this.barbeiroId,
      barbeiroNome: barbeiroNome ?? this.barbeiroNome,
      status: status ?? this.status,
      total: total ?? this.total,
      comissaoTotal: comissaoTotal ?? this.comissaoTotal,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      dataAbertura: dataAbertura ?? this.dataAbertura,
      dataFechamento: dataFechamento ?? this.dataFechamento,
      observacoes: observacoes ?? this.observacoes,
      itens: itens ?? this.itens,
    );
  }

  @override
  String toString() =>
      'Comanda(id: $id, cliente: $clienteNome, status: $status, total: $total)';
}
