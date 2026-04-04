// ============================================================
// caixa.dart
// Model que representa a abertura e fechamento de caixa diário.
// Controla o resumo financeiro por forma de pagamento.
// ============================================================

class Caixa {
  final int? id;
  final DateTime dataAbertura;
  final DateTime? dataFechamento;
  /// Valor inicial colocado no caixa ao abrir
  final double valorInicial;
  /// Valor total calculado ao fechar
  final double? valorFinal;
  /// 'aberto' ou 'fechado'
  final String status;
  /// Resumo por forma de pagamento (JSON serializado)
  final String? resumoPagamentos;
  final String? observacoes;

  const Caixa({
    this.id,
    required this.dataAbertura,
    this.dataFechamento,
    this.valorInicial = 0.0,
    this.valorFinal,
    this.status = 'aberto',
    this.resumoPagamentos,
    this.observacoes,
  });

  factory Caixa.fromMap(Map<String, dynamic> map) {
    return Caixa(
      id: map['id'] as int?,
      dataAbertura: DateTime.parse(map['data_abertura'] as String),
      dataFechamento: map['data_fechamento'] != null
          ? DateTime.parse(map['data_fechamento'] as String)
          : null,
      valorInicial: (map['valor_inicial'] as num?)?.toDouble() ?? 0.0,
      valorFinal: (map['valor_final'] as num?)?.toDouble(),
      status: (map['status'] as String?) ?? 'aberto',
      resumoPagamentos: map['resumo_pagamentos'] as String?,
      observacoes: map['observacoes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'data_abertura': dataAbertura.toIso8601String(),
      'data_fechamento': dataFechamento?.toIso8601String(),
      'valor_inicial': valorInicial,
      'valor_final': valorFinal,
      'status': status,
      'resumo_pagamentos': resumoPagamentos,
      'observacoes': observacoes,
    };
  }

  bool get isAberto => status == 'aberto';

  Caixa copyWith({
    int? id,
    DateTime? dataAbertura,
    DateTime? dataFechamento,
    double? valorInicial,
    double? valorFinal,
    String? status,
    String? resumoPagamentos,
    String? observacoes,
  }) {
    return Caixa(
      id: id ?? this.id,
      dataAbertura: dataAbertura ?? this.dataAbertura,
      dataFechamento: dataFechamento ?? this.dataFechamento,
      valorInicial: valorInicial ?? this.valorInicial,
      valorFinal: valorFinal ?? this.valorFinal,
      status: status ?? this.status,
      resumoPagamentos: resumoPagamentos ?? this.resumoPagamentos,
      observacoes: observacoes ?? this.observacoes,
    );
  }

  @override
  String toString() =>
      'Caixa(id: $id, status: $status, abertura: $dataAbertura)';
}
